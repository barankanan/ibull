"use client";

import {
  ReactNode,
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  useTransition,
} from "react";
import {
  RestaurantMutationDraft,
  RestaurantMutationInput,
  RestaurantMutationResult,
} from "@/features/restaurant/domain/commands";
import { RestaurantRuntimeError } from "@/features/restaurant/domain/errors";
import { RestaurantStoreState } from "@/features/restaurant/domain/model";
import {
  applyRestaurantMutation,
  cloneRestaurantState,
  extractChangedTables,
} from "@/features/restaurant/domain/reducer";
import { createRestaurantClientAdapter } from "@/features/restaurant/data/client";
import { RestaurantClientAdapter } from "@/features/restaurant/data/shared/repository";
import { createInitialState } from "@/lib/mock-data";
import { makeId } from "@/lib/utils";

interface WaiterStoreContextValue {
  state: RestaurantStoreState;
  serverState: RestaurantStoreState;
  isLoading: boolean;
  isMutating: boolean;
  pendingMutationIds: string[];
  dirtyTableIds: string[];
  lastError: RestaurantRuntimeError | null;
  applyLocalMutation: (mutation: RestaurantMutationDraft) => RestaurantMutationInput;
  executeMutation: (
    mutation: RestaurantMutationDraft,
    options?: { optimistic?: boolean },
  ) => Promise<RestaurantMutationResult>;
  retryLastMutation: () => Promise<RestaurantMutationResult | null>;
  refresh: () => Promise<void>;
  discardLocalChanges: (tableId?: string) => void;
}

const WaiterStoreContext = createContext<WaiterStoreContextValue | null>(null);

function unique(values: string[]) {
  return Array.from(new Set(values));
}

function enrichMutation(
  draft: RestaurantMutationDraft,
  snapshot: RestaurantStoreState,
): RestaurantMutationInput {
  const createdAt = draft.createdAt ?? new Date().toISOString();
  const base = {
    ...draft,
    createdAt,
    clientMutationId: draft.clientMutationId ?? makeId("mutation"),
  } as RestaurantMutationInput;

  if ("tableId" in base && typeof base.expectedTableVersion !== "number") {
    const table = snapshot.tables.find((entry) => entry.id === base.tableId);
    base.expectedTableVersion = table?.version ?? 0;
  }

  if ("sourceTableId" in base) {
    if (typeof base.expectedTableVersion !== "number") {
      const source = snapshot.tables.find((entry) => entry.id === base.sourceTableId);
      base.expectedTableVersion = source?.version ?? 0;
    }
    if (typeof base.expectedTargetTableVersion !== "number") {
      const target = snapshot.tables.find((entry) => entry.id === base.targetTableId);
      base.expectedTargetTableVersion = target?.version ?? 0;
    }
  }

  return base;
}

export function WaiterStoreProvider({
  children,
  initialState,
  adapter,
}: {
  children: ReactNode;
  initialState?: RestaurantStoreState;
  adapter?: RestaurantClientAdapter;
}) {
  const resolvedAdapter = useMemo(
    () => adapter ?? createRestaurantClientAdapter(),
    [adapter],
  );

  const fallbackState = useMemo(() => createInitialState(), []);
  const [serverState, setServerState] = useState<RestaurantStoreState>(
    initialState ?? fallbackState,
  );
  const [state, setState] = useState<RestaurantStoreState>(initialState ?? fallbackState);
  const [isLoading, setIsLoading] = useState(!initialState);
  const [pendingMutationIds, setPendingMutationIds] = useState<string[]>([]);
  const [dirtyTableIds, setDirtyTableIds] = useState<string[]>([]);
  const [lastError, setLastError] = useState<RestaurantRuntimeError | null>(null);
  const [lastFailedMutation, setLastFailedMutation] =
    useState<RestaurantMutationDraft | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    if (!initialState) return;
    setServerState(initialState);
    setState(initialState);
    setDirtyTableIds([]);
  }, [initialState]);

  useEffect(() => {
    if (initialState) return;
    void refreshSnapshot();
  }, [initialState]);

  async function refreshSnapshot() {
    setIsLoading(true);
    try {
      const response = await resolvedAdapter.getSnapshot();
      startTransition(() => {
        setServerState(response.snapshot);
        setState(response.snapshot);
        setDirtyTableIds([]);
        setLastError(null);
        setLastFailedMutation(null);
      });
    } catch (error) {
      const runtimeError =
        error instanceof RestaurantRuntimeError
          ? error
          : new RestaurantRuntimeError(
              "SNAPSHOT_REFRESH_FAILED",
              "Snapshot yenilenemedi.",
              { retriable: true, details: error },
            );
      startTransition(() => {
        setLastError(runtimeError);
      });
    } finally {
      setIsLoading(false);
    }
  }

  function applyLocalMutation(mutationDraft: RestaurantMutationDraft) {
    const mutation = enrichMutation(mutationDraft, state);
    const changedTableIds = extractChangedTables(mutation);
    startTransition(() => {
      setState((current) => applyRestaurantMutation(current, mutation));
      setDirtyTableIds((current) => unique([...current, ...changedTableIds]));
      setLastError(null);
    });
    return mutation;
  }

  async function executeMutation(
    mutationDraft: RestaurantMutationDraft,
    options?: { optimistic?: boolean },
  ) {
    const mutation = enrichMutation(mutationDraft, state);
    const changedTableIds = extractChangedTables(mutation);
    const rollbackState = cloneRestaurantState(state);

    if (options?.optimistic !== false) {
      startTransition(() => {
        setState((current) => applyRestaurantMutation(current, mutation));
      });
    }

    setPendingMutationIds((current) => [...current, mutation.clientMutationId]);

    try {
      const result = await resolvedAdapter.execute(mutation);
      startTransition(() => {
        setServerState(result.snapshot);
        setState(result.snapshot);
        setDirtyTableIds((current) =>
          current.filter((tableId) => !result.changedTableIds.includes(tableId)),
        );
        setLastError(null);
        setLastFailedMutation(null);
      });
      return result;
    } catch (error) {
      const runtimeError =
        error instanceof RestaurantRuntimeError
          ? error
          : new RestaurantRuntimeError(
              "MUTATION_FAILED",
              "Islem kaydedilemedi.",
              {
                retriable: true,
                details: error,
              },
            );
      const rollbackSnapshot = runtimeError.snapshot ?? serverState ?? rollbackState;
      startTransition(() => {
        if (runtimeError.snapshot) {
          setServerState(runtimeError.snapshot);
        }
        setState(rollbackSnapshot);
        setDirtyTableIds((current) =>
          current.filter((tableId) => !changedTableIds.includes(tableId)),
        );
        setLastError(runtimeError);
        setLastFailedMutation(mutationDraft);
      });
      throw runtimeError;
    } finally {
      setPendingMutationIds((current) =>
        current.filter((item) => item !== mutation.clientMutationId),
      );
    }
  }

  async function retryLastMutation() {
    if (!lastFailedMutation) {
      return null;
    }
    return executeMutation(lastFailedMutation, {
      optimistic: false,
    });
  }

  function discardLocalChanges(tableId?: string) {
    startTransition(() => {
      if (!tableId) {
        setState(serverState);
        setDirtyTableIds([]);
        return;
      }

      setState((current) => ({
        ...current,
        tables: current.tables.map((table) =>
          table.id === tableId
            ? cloneRestaurantState(serverState).tables.find((entry) => entry.id === tableId) ??
              table
            : table,
        ),
      }));
      setDirtyTableIds((current) => current.filter((id) => id !== tableId));
    });
  }

  return (
    <WaiterStoreContext.Provider
      value={{
        state,
        serverState,
        isLoading,
        isMutating: pendingMutationIds.length > 0 || isPending,
        pendingMutationIds,
        dirtyTableIds,
        lastError,
        applyLocalMutation,
        executeMutation,
        retryLastMutation,
        refresh: refreshSnapshot,
        discardLocalChanges,
      }}
    >
      {children}
    </WaiterStoreContext.Provider>
  );
}

export function useWaiterStore() {
  const context = useContext(WaiterStoreContext);
  if (!context) {
    throw new Error("useWaiterStore must be used within WaiterStoreProvider");
  }
  return context;
}

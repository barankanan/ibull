export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Database {
  restaurant: {
    Tables: {
      venues: {
        Row: {
          id: string;
          name: string;
          code: string;
          timezone: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          code: string;
          timezone?: string;
          created_at?: string;
        };
        Update: Partial<Database["restaurant"]["Tables"]["venues"]["Insert"]>;
      };
      customers: {
        Row: {
          id: string;
          venue_id: string;
          name: string;
          phone: string;
          company: string | null;
          loyalty_tier: "Yeni" | "Gumus" | "Altin";
          visit_count: number;
          average_spend: number;
          favorite_product_ids: string[];
          notes: string[];
          last_visit_at: string | null;
          revision: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          venue_id: string;
          name: string;
          phone: string;
          company?: string | null;
          loyalty_tier?: "Yeni" | "Gumus" | "Altin";
          visit_count?: number;
          average_spend?: number;
          favorite_product_ids?: string[];
          notes?: string[];
          last_visit_at?: string | null;
          revision?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<Database["restaurant"]["Tables"]["customers"]["Insert"]>;
      };
      product_categories: {
        Row: {
          id: string;
          venue_id: string;
          name: string;
          description: string;
          sort_order: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          venue_id: string;
          name: string;
          description?: string;
          sort_order?: number;
          created_at?: string;
        };
        Update: Partial<Database["restaurant"]["Tables"]["product_categories"]["Insert"]>;
      };
      products: {
        Row: {
          id: string;
          venue_id: string;
          category_id: string;
          sku: string | null;
          name: string;
          description: string;
          base_price: number;
          kind: "standard" | "weighted" | "service";
          stock_state: "in_stock" | "low" | "out";
          stock_label: string;
          prep_minutes: number;
          visual_tone: "plum" | "rose" | "blue" | "mint" | "amber";
          quick_weight_options: number[] | null;
          suggestion_ids: string[] | null;
          tags: string[] | null;
          is_favorite: boolean;
          is_popular: boolean;
          revision: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          venue_id: string;
          category_id: string;
          sku?: string | null;
          name: string;
          description?: string;
          base_price: number;
          kind?: "standard" | "weighted" | "service";
          stock_state?: "in_stock" | "low" | "out";
          stock_label?: string;
          prep_minutes?: number;
          visual_tone?: "plum" | "rose" | "blue" | "mint" | "amber";
          quick_weight_options?: number[] | null;
          suggestion_ids?: string[] | null;
          tags?: string[] | null;
          is_favorite?: boolean;
          is_popular?: boolean;
          revision?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<Database["restaurant"]["Tables"]["products"]["Insert"]>;
      };
      tables: {
        Row: {
          id: string;
          venue_id: string;
          active_session_id: string | null;
          name: string;
          zone: string;
          seat_count: number;
          guest_count: number;
          status:
            | "empty"
            | "active"
            | "kitchen_sent"
            | "preparing"
            | "ready"
            | "served"
            | "payment_pending"
            | "completed";
          opened_at: string;
          last_action_at: string;
          current_customer_id: string | null;
          reservation_payload: Json | null;
          reference_code: string | null;
          barcode: string | null;
          timed_billing_enabled: boolean;
          timed_billing_started_at: string | null;
          timed_billing_rate_per_hour: number | null;
          revision: number;
          updated_by: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          venue_id: string;
          active_session_id?: string | null;
          name: string;
          zone: string;
          seat_count: number;
          guest_count?: number;
          status?:
            | "empty"
            | "active"
            | "kitchen_sent"
            | "preparing"
            | "ready"
            | "served"
            | "payment_pending"
            | "completed";
          opened_at?: string;
          last_action_at?: string;
          current_customer_id?: string | null;
          reservation_payload?: Json | null;
          reference_code?: string | null;
          barcode?: string | null;
          timed_billing_enabled?: boolean;
          timed_billing_started_at?: string | null;
          timed_billing_rate_per_hour?: number | null;
          revision?: number;
          updated_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<Database["restaurant"]["Tables"]["tables"]["Insert"]>;
      };
      table_drafts: {
        Row: {
          id: string;
          table_id: string;
          editing_check_id: string | null;
          updated_at: string;
          revision: number;
        };
        Insert: {
          id?: string;
          table_id: string;
          editing_check_id?: string | null;
          updated_at?: string;
          revision?: number;
        };
        Update: Partial<Database["restaurant"]["Tables"]["table_drafts"]["Insert"]>;
      };
      draft_items: {
        Row: {
          id: string;
          draft_id: string;
          product_id: string;
          name: string;
          kind: "standard" | "weighted" | "service";
          quantity: number;
          unit_price: number;
          total_price: number;
          status: "draft";
          customizations_payload: Json;
          service_payload: Json | null;
          created_at: string;
          updated_at: string;
          revision: number;
        };
        Insert: {
          id?: string;
          draft_id: string;
          product_id: string;
          name: string;
          kind?: "standard" | "weighted" | "service";
          quantity?: number;
          unit_price: number;
          total_price: number;
          status?: "draft";
          customizations_payload?: Json;
          service_payload?: Json | null;
          created_at?: string;
          updated_at?: string;
          revision?: number;
        };
        Update: Partial<Database["restaurant"]["Tables"]["draft_items"]["Insert"]>;
      };
      checks: {
        Row: {
          id: string;
          table_id: string;
          label: string;
          status:
            | "draft"
            | "kitchen_sent"
            | "preparing"
            | "ready"
            | "served"
            | "payment_pending"
            | "completed";
          note: string | null;
          source: "waiter" | "qr" | "system";
          total_amount: number;
          created_at: string;
          updated_at: string;
          revision: number;
        };
        Insert: {
          id?: string;
          table_id: string;
          label: string;
          status?:
            | "draft"
            | "kitchen_sent"
            | "preparing"
            | "ready"
            | "served"
            | "payment_pending"
            | "completed";
          note?: string | null;
          source?: "waiter" | "qr" | "system";
          total_amount?: number;
          created_at?: string;
          updated_at?: string;
          revision?: number;
        };
        Update: Partial<Database["restaurant"]["Tables"]["checks"]["Insert"]>;
      };
      check_items: {
        Row: {
          id: string;
          check_id: string;
          product_id: string;
          name: string;
          kind: "standard" | "weighted" | "service";
          quantity: number;
          unit_price: number;
          total_price: number;
          status:
            | "draft"
            | "kitchen_sent"
            | "preparing"
            | "ready"
            | "served"
            | "payment_pending"
            | "completed";
          customizations_payload: Json;
          service_payload: Json | null;
          created_at: string;
          updated_at: string;
          revision: number;
        };
        Insert: {
          id?: string;
          check_id: string;
          product_id: string;
          name: string;
          kind?: "standard" | "weighted" | "service";
          quantity?: number;
          unit_price: number;
          total_price: number;
          status?:
            | "draft"
            | "kitchen_sent"
            | "preparing"
            | "ready"
            | "served"
            | "payment_pending"
            | "completed";
          customizations_payload?: Json;
          service_payload?: Json | null;
          created_at?: string;
          updated_at?: string;
          revision?: number;
        };
        Update: Partial<Database["restaurant"]["Tables"]["check_items"]["Insert"]>;
      };
      partial_payments: {
        Row: {
          id: string;
          table_id: string;
          amount: number;
          method: "cash" | "card" | "meal_card" | "qr" | "voucher";
          kind: "partial" | "closing";
          note: string | null;
          remaining_after_payment: number | null;
          created_at: string;
          revision: number;
        };
        Insert: {
          id?: string;
          table_id: string;
          amount: number;
          method: "cash" | "card" | "meal_card" | "qr" | "voucher";
          kind?: "partial" | "closing";
          note?: string | null;
          remaining_after_payment?: number | null;
          created_at?: string;
          revision?: number;
        };
        Update: Partial<Database["restaurant"]["Tables"]["partial_payments"]["Insert"]>;
      };
      split_plans: {
        Row: {
          id: string;
          table_id: string;
          mode: "product" | "person" | "amount";
          note: string | null;
          created_at: string;
          revision: number;
        };
        Insert: {
          id?: string;
          table_id: string;
          mode: "product" | "person" | "amount";
          note?: string | null;
          created_at?: string;
          revision?: number;
        };
        Update: Partial<Database["restaurant"]["Tables"]["split_plans"]["Insert"]>;
      };
      split_plan_parts: {
        Row: {
          id: string;
          split_plan_id: string;
          label: string;
          amount: number;
          line_item_ids: string[];
          created_at: string;
        };
        Insert: {
          id?: string;
          split_plan_id: string;
          label: string;
          amount: number;
          line_item_ids?: string[];
          created_at?: string;
        };
        Update: Partial<Database["restaurant"]["Tables"]["split_plan_parts"]["Insert"]>;
      };
      operation_logs: {
        Row: {
          id: string;
          venue_id: string;
          table_id: string | null;
          operation_key: string;
          type: string;
          title: string;
          description: string;
          status: "pending" | "committed" | "rolled_back";
          severity: "info" | "success" | "warning" | "error";
          actor_user_id: string | null;
          actor_name: string | null;
          client_mutation_id: string | null;
          payload: Json;
          created_at: string;
        };
        Insert: {
          id?: string;
          venue_id: string;
          table_id?: string | null;
          operation_key: string;
          type: string;
          title: string;
          description: string;
          status?: "pending" | "committed" | "rolled_back";
          severity?: "info" | "success" | "warning" | "error";
          actor_user_id?: string | null;
          actor_name?: string | null;
          client_mutation_id?: string | null;
          payload?: Json;
          created_at?: string;
        };
        Update: Partial<Database["restaurant"]["Tables"]["operation_logs"]["Insert"]>;
      };
      print_logs: {
        Row: {
          id: string;
          venue_id: string;
          table_id: string;
          table_name: string;
          check_id: string | null;
          order_reference: string | null;
          print_type: "adisyon" | "mutfak";
          printer_target: string | null;
          requested_by: string | null;
          status: "pending" | "printed" | "failed";
          total_amount: number;
          payload: Json;
          created_at: string;
          printed_at: string | null;
        };
        Insert: {
          id?: string;
          venue_id: string;
          table_id: string;
          table_name: string;
          check_id?: string | null;
          order_reference?: string | null;
          print_type: "adisyon" | "mutfak";
          printer_target?: string | null;
          requested_by?: string | null;
          status?: "pending" | "printed" | "failed";
          total_amount?: number;
          payload?: Json;
          created_at?: string;
          printed_at?: string | null;
        };
        Update: Partial<Database["restaurant"]["Tables"]["print_logs"]["Insert"]>;
      };
    };
    Functions: {
      replace_draft_items: {
        Args: {
          p_table_id: string;
          p_expected_revision: number;
          p_editing_check_id: string | null;
          p_items: Json;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      upsert_check_from_draft: {
        Args: {
          p_table_id: string;
          p_expected_revision: number;
          p_editing_check_id: string | null;
          p_items: Json;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      advance_check_status: {
        Args: {
          p_table_id: string;
          p_check_id: string;
          p_expected_revision: number;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      update_check_item: {
        Args: {
          p_table_id: string;
          p_check_id: string;
          p_item_id: string;
          p_expected_revision: number;
          p_updates: Json;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      remove_check_item: {
        Args: {
          p_table_id: string;
          p_check_id: string;
          p_item_id: string;
          p_expected_revision: number;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      move_check_items: {
        Args: {
          p_source_table_id: string;
          p_target_table_id: string;
          p_item_ids: string[];
          p_expected_source_revision: number;
          p_expected_target_revision: number;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      take_partial_payment: {
        Args: {
          p_table_id: string;
          p_expected_revision: number;
          p_amount: number;
          p_method: "cash" | "card" | "meal_card" | "qr" | "voucher";
          p_kind: "partial" | "closing";
          p_note: string | null;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      transfer_table: {
        Args: {
          p_source_table_id: string;
          p_target_table_id: string;
          p_expected_source_revision: number;
          p_expected_target_revision: number;
          p_mode: "all" | "merge" | "draft-only";
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      create_split_plan: {
        Args: {
          p_table_id: string;
          p_expected_revision: number;
          p_mode: "product" | "person" | "amount";
          p_parts: Json;
          p_note: string | null;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      assign_customer: {
        Args: {
          p_table_id: string;
          p_expected_revision: number;
          p_customer_id: string | null;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      create_customer_and_assign: {
        Args: {
          p_table_id: string;
          p_expected_revision: number;
          p_customer_payload: Json;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      register_print_log: {
        Args: {
          p_table_id: string;
          p_expected_revision: number;
          p_print_type: "adisyon" | "mutfak";
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
      reset_table_for_new_bill: {
        Args: {
          p_table_id: string;
          p_expected_revision: number;
          p_client_mutation_id: string;
          p_actor_name: string | null;
        };
        Returns: Json;
      };
    };
  };
}

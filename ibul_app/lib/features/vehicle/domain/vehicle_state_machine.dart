import '../models/vehicle_enums.dart';

/// Controlled listing / reservation transitions. Invalid hops throw.
abstract final class VehicleStateMachine {
  static const listingGraph = <VehicleListingStatus, Set<VehicleListingStatus>>{
    VehicleListingStatus.draft: {
      VehicleListingStatus.pendingReview,
      VehicleListingStatus.inactive,
    },
    VehicleListingStatus.pendingReview: {
      VehicleListingStatus.active,
      VehicleListingStatus.draft,
      VehicleListingStatus.inactive,
    },
    VehicleListingStatus.active: {
      VehicleListingStatus.reserved,
      VehicleListingStatus.sold,
      VehicleListingStatus.rented,
      VehicleListingStatus.maintenance,
      VehicleListingStatus.inactive,
      VehicleListingStatus.draft,
    },
    VehicleListingStatus.reserved: {
      VehicleListingStatus.active,
      VehicleListingStatus.rented,
      VehicleListingStatus.sold,
      VehicleListingStatus.inactive,
    },
    VehicleListingStatus.rented: {
      VehicleListingStatus.returnPending,
      VehicleListingStatus.maintenance,
    },
    VehicleListingStatus.returnPending: {
      VehicleListingStatus.active,
      VehicleListingStatus.maintenance,
    },
    VehicleListingStatus.maintenance: {
      VehicleListingStatus.active,
      VehicleListingStatus.inactive,
    },
    VehicleListingStatus.sold: {VehicleListingStatus.inactive},
    VehicleListingStatus.inactive: {
      VehicleListingStatus.draft,
      VehicleListingStatus.pendingReview,
    },
  };

  static const reservationGraph =
      <VehicleReservationStatus, Set<VehicleReservationStatus>>{
        VehicleReservationStatus.pendingDocs: {
          VehicleReservationStatus.pendingSellerReview,
          VehicleReservationStatus.pendingPayment,
          VehicleReservationStatus.cancelled,
        },
        VehicleReservationStatus.pendingSellerReview: {
          VehicleReservationStatus.pendingPayment,
          VehicleReservationStatus.rejected,
          VehicleReservationStatus.cancelled,
        },
        VehicleReservationStatus.pendingPayment: {
          VehicleReservationStatus.confirmed,
          VehicleReservationStatus.reserved,
          VehicleReservationStatus.cancelled,
          VehicleReservationStatus.rejected,
          VehicleReservationStatus.sellerCancelled,
          VehicleReservationStatus.refundPending,
        },
        VehicleReservationStatus.confirmed: {
          VehicleReservationStatus.reserved,
          VehicleReservationStatus.cancelled,
          VehicleReservationStatus.sellerCancelled,
          VehicleReservationStatus.refundPending,
        },
        VehicleReservationStatus.reserved: {
          VehicleReservationStatus.activeRental,
          VehicleReservationStatus.cancelled,
          VehicleReservationStatus.sellerCancelled,
          VehicleReservationStatus.refundPending,
        },
        VehicleReservationStatus.activeRental: {
          VehicleReservationStatus.returnPending,
        },
        VehicleReservationStatus.returnPending: {
          VehicleReservationStatus.completed,
        },
        VehicleReservationStatus.completed: {},
        VehicleReservationStatus.cancelled: {},
        VehicleReservationStatus.rejected: {
          VehicleReservationStatus.refundPending,
        },
        VehicleReservationStatus.refundPending: {
          VehicleReservationStatus.cancelled,
          VehicleReservationStatus.rejected,
          VehicleReservationStatus.sellerCancelled,
        },
        VehicleReservationStatus.sellerCancelled: {
          VehicleReservationStatus.refundPending,
        },
      };

  static bool canTransitionListing(
    VehicleListingStatus from,
    VehicleListingStatus to,
  ) {
    if (from == to) return true;
    return listingGraph[from]?.contains(to) ?? false;
  }

  static bool canTransitionReservation(
    VehicleReservationStatus from,
    VehicleReservationStatus to,
  ) {
    if (from == to) return true;
    return reservationGraph[from]?.contains(to) ?? false;
  }

  static VehicleListingStatus transitionListing(
    VehicleListingStatus from,
    VehicleListingStatus to,
  ) {
    if (!canTransitionListing(from, to)) {
      throw StateError('Invalid listing transition ${from.wire} → ${to.wire}');
    }
    return to;
  }

  static VehicleReservationStatus transitionReservation(
    VehicleReservationStatus from,
    VehicleReservationStatus to,
  ) {
    if (!canTransitionReservation(from, to)) {
      throw StateError(
        'Invalid reservation transition ${from.wire} → ${to.wire}',
      );
    }
    return to;
  }
}

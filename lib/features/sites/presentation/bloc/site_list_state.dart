part of 'site_list_bloc.dart';

enum SiteListStatus { initial, loading, success, failure }

class SiteListState extends Equatable {
  final SiteListStatus status;
  final List<SiteData> sites;
  final String? error;

  const SiteListState({
    this.status = SiteListStatus.initial,
    this.sites = const [],
    this.error,
  });

  SiteListState copyWith({
    SiteListStatus? status,
    List<SiteData>? sites,
    String? error,
  }) {
    return SiteListState(
      status: status ?? this.status,
      sites: sites ?? this.sites,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, sites, error];
}

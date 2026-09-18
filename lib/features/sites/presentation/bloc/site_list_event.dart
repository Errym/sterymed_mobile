part of 'site_list_bloc.dart';

abstract class SiteListEvent extends Equatable {
  const SiteListEvent();
  @override
  List<Object?> get props => [];
}

class LoadSites extends SiteListEvent {
  const LoadSites();
}

class RefreshSites extends SiteListEvent {
  const RefreshSites();
}

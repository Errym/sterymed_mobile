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

class CreateSite extends SiteListEvent {
  final String name;
  final String? addressLine1;
  final String? city;
  final bool isPrimary;
  const CreateSite({
    required this.name,
    this.addressLine1,
    this.city,
    this.isPrimary = false,
  });
  @override
  List<Object?> get props => [name];
}

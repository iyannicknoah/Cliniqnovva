import '../../browse/models/branch_summary.dart';
import '../../browse/providers/browse_provider.dart';

/// Fixed sample data for `/dev/home-preview` (see app_router.dart) — the
/// ONLY way to see the Home screen's design without a real login, since
/// live login is still blocked by the known Firebase project mismatch
/// (docs/known-issues.md). Never referenced from the real app flow —
/// `homeBrowseProvider` is overridden with this in a route-scoped
/// `ProviderScope`, not swapped in globally.
const sampleHomeBrowseData = HomeBrowseData(
  services: [
    'General Medicine',
    'Pediatrics',
    'Dental',
    'Cardiology',
    'Dermatology',
  ],
  popular: [
    BranchSummary(
      id: 'sample-1',
      clinicId: 'sample-clinic',
      name: 'City Medical Center',
      displayName: 'City Medical Center',
      imageUrl: 'https://picsum.photos/id/1005/800/500',
      doctorCount: 15,
      servicesOffered: ['General Medicine', 'Pediatrics', 'Dental'],
      averageRating: 4.8,
      reviewCount: 132,
      popularityScore: 95,
    ),
    BranchSummary(
      id: 'sample-3',
      clinicId: 'sample-clinic',
      name: 'Sunrise Family Clinic',
      displayName: 'Sunrise Family Clinic',
      imageUrl: 'https://picsum.photos/id/1011/800/500',
      doctorCount: 22,
      servicesOffered: ['Pediatrics', 'Dermatology'],
      averageRating: 4.9,
      reviewCount: 210,
      popularityScore: 98,
    ),
  ],
  newOnes: [
    BranchSummary(
      id: 'sample-2',
      clinicId: 'sample-clinic',
      name: 'Kigali Wellness Clinic',
      displayName: 'Kigali Wellness Clinic',
      imageUrl: 'https://picsum.photos/id/1074/800/500',
      doctorCount: 9,
      servicesOffered: ['Cardiology', 'Dermatology'],
      averageRating: 4.6,
      reviewCount: 3,
      popularityScore: 40,
    ),
  ],
);

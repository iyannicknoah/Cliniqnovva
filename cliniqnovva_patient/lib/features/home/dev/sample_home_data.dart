import '../../browse/models/branch_summary.dart';
import '../../browse/models/service_summary.dart';
import '../../browse/providers/browse_provider.dart';

/// Fixed sample data for `/dev/home-preview` (see app_router.dart) — the
/// ONLY way to see the Home screen's design without a real login, since
/// live login is still blocked by the known Firebase project mismatch
/// (docs/known-issues.md). Consumed directly by `HomePreviewScreen` (plain
/// data, no provider involved) — never referenced from the real app flow.
/// 6 `popular` entries (not 2) so the preview actually demonstrates the
/// real Home screen's `.take(6)` cap, not just a couple of cards.
const sampleHomeBrowseData = HomeBrowseData(
  services: [
    ServiceSummary(name: 'General Medicine', clinicCount: 12),
    ServiceSummary(name: 'Pediatrics', clinicCount: 9),
    ServiceSummary(name: 'Dental', clinicCount: 6),
    ServiceSummary(name: 'Cardiology', clinicCount: 4),
    ServiceSummary(name: 'Dermatology', clinicCount: 3),
  ],
  popular: [
    BranchSummary(
      id: 'sample-1',
      clinicId: 'sample-clinic',
      name: 'City Medical Center',
      displayName: 'City Medical Center',
      publicAddress: 'KG 7 Ave, Kimironko, Kigali',
      imageUrl: 'https://picsum.photos/id/1005/800/500',
      doctorCount: 15,
      servicesOffered: ['General Medicine', 'Pediatrics', 'Dental'],
      averageRating: 4.8,
      reviewCount: 132,
      popularityScore: 95,
    ),
    BranchSummary(
      id: 'sample-2',
      clinicId: 'sample-clinic',
      name: 'Sunrise Family Clinic',
      displayName: 'Sunrise Family Clinic',
      publicAddress: 'KN 3 Rd, Nyarugenge, Kigali',
      imageUrl: 'https://picsum.photos/id/1011/800/500',
      doctorCount: 22,
      servicesOffered: ['Pediatrics', 'Dermatology'],
      averageRating: 4.9,
      reviewCount: 210,
      popularityScore: 98,
    ),
    BranchSummary(
      id: 'sample-3',
      clinicId: 'sample-clinic',
      name: 'Kigali Wellness Clinic',
      displayName: 'Kigali Wellness Clinic',
      publicAddress: 'KG 11 Ave, Remera, Kigali',
      imageUrl: 'https://picsum.photos/id/1074/800/500',
      doctorCount: 9,
      servicesOffered: ['Cardiology', 'Dermatology'],
      averageRating: 4.6,
      reviewCount: 87,
      popularityScore: 88,
    ),
    BranchSummary(
      id: 'sample-4',
      clinicId: 'sample-clinic',
      name: 'Hope Dental Care',
      displayName: 'Hope Dental Care',
      publicAddress: 'KK 15 Rd, Kicukiro, Kigali',
      imageUrl: 'https://picsum.photos/id/1025/800/500',
      doctorCount: 6,
      servicesOffered: ['Dental'],
      averageRating: 4.7,
      reviewCount: 64,
      popularityScore: 80,
    ),
    BranchSummary(
      id: 'sample-5',
      clinicId: 'sample-clinic',
      name: 'Rwanda Heart Institute',
      displayName: 'Rwanda Heart Institute',
      publicAddress: 'KG 9 Ave, Kacyiru, Kigali',
      imageUrl: 'https://picsum.photos/id/1035/800/500',
      doctorCount: 11,
      servicesOffered: ['Cardiology', 'General Medicine'],
      averageRating: 4.5,
      reviewCount: 51,
      popularityScore: 75,
    ),
    BranchSummary(
      id: 'sample-6',
      clinicId: 'sample-clinic',
      name: 'Green Valley Pediatrics',
      displayName: 'Green Valley Pediatrics',
      publicAddress: 'KN 78 St, Gasabo, Kigali',
      imageUrl: 'https://picsum.photos/id/1041/800/500',
      doctorCount: 8,
      servicesOffered: ['Pediatrics'],
      averageRating: 4.9,
      reviewCount: 39,
      popularityScore: 70,
    ),
  ],
  newOnes: [],
);

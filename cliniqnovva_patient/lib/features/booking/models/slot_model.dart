/// One bookable `{startTime, endTime}` pair — GET
/// /api/v1/appointments/available-slots's `slots` array (`appointments.
/// service.js#getAvailableSlots`).
class SlotModel {
  const SlotModel({required this.startTime, required this.endTime});

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(startTime: json['startTime'] as String, endTime: json['endTime'] as String);
  }

  final String startTime;
  final String endTime;
}

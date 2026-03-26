#pragma once

#include <cstdint>
#include <string>
#include <vector>

// MBTI types in index order (matches Dart kMbtiTypes list).
static const char* const kMbtiTypes[16] = {
    "INTJ", "INTP", "ENTJ", "ENTP",
    "INFJ", "INFP", "ENFJ", "ENFP",
    "ISTJ", "ISFJ", "ESTJ", "ESFJ",
    "ISTP", "ISFP", "ESTP", "ESFP",
};

// Custom 128-bit BLE service UUID used by both peripheral and central.
static const char* const kSWServiceUUID = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890";

// Payload format (max 20 bytes in BLE service data field):
//   Offset  Len  Field
//     0      1   mbti_index  (0–15)
//     1      1   name_len    (number of UTF-8 bytes, max 18)
//     2      N   name_utf8
static const size_t kMaxNameBytes = 18;

struct SWProfile {
    uint8_t mbti_index = 0;  // 0–15
    std::string name;        // UTF-8, clamped to kMaxNameBytes bytes
};

// Encode profile into service data bytes.
// Returns empty vector if mbti_index >= 16.
std::vector<uint8_t> sw_profile_encode(const SWProfile& profile);

// Decode service data bytes into profile.
// Returns false if data is malformed or too short.
bool sw_profile_decode(const uint8_t* data, size_t len, SWProfile& out);

// Resolve mbti_index to its string (e.g. "ENFP").
// Returns "" for out-of-range index.
const char* sw_mbti_name(uint8_t index);

// ---------------------------------------------------------------------------
// Distance estimation
// ---------------------------------------------------------------------------

enum class SWDistanceCategory {
    very_close,  // RSSI > -60 dBm  (~< 1 m)
    near,        // -60 to -75 dBm  (1–3 m)
    medium,      // -75 to -85 dBm  (3–10 m)
    far,         // RSSI < -85 dBm  (> 10 m)
};

// Estimate proximity category from raw RSSI value.
SWDistanceCategory sw_rssi_to_distance(int rssi);

// Return the string label for a distance category.
// Returns: "very_close" / "near" / "medium" / "far"
const char* sw_distance_name(SWDistanceCategory d);

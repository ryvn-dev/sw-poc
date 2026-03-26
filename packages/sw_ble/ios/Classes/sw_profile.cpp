#include "sw_profile.h"
#include <cstring>

// Truncate UTF-8 string to at most max_bytes bytes without splitting a
// multi-byte codepoint. Scans backwards from the byte limit to find a safe
// boundary.
static size_t utf8_safe_len(const std::string& s, size_t max_bytes) {
    if (s.size() <= max_bytes) return s.size();
    size_t len = max_bytes;
    // Walk backwards until we find a byte that is NOT a UTF-8 continuation
    // byte (0x80–0xBF). This lands us at the start of the last incomplete
    // codepoint, which we then exclude.
    while (len > 0 && (static_cast<uint8_t>(s[len]) & 0xC0) == 0x80) {
        --len;
    }
    // If len > 0 and the byte at len is the start of a multi-byte sequence,
    // drop it too (it would be incomplete after truncation).
    if (len > 0) {
        uint8_t b = static_cast<uint8_t>(s[len]);
        if (b >= 0xC0) {
            // This is the leading byte of a 2–4 byte sequence; exclude it.
            --len;
        }
    }
    return len;
}

std::vector<uint8_t> sw_profile_encode(const SWProfile& profile) {
    if (profile.mbti_index >= 16) return {};

    size_t name_len = utf8_safe_len(profile.name, kMaxNameBytes);

    std::vector<uint8_t> out;
    out.reserve(2 + name_len);
    out.push_back(profile.mbti_index);
    out.push_back(static_cast<uint8_t>(name_len));
    out.insert(out.end(),
               reinterpret_cast<const uint8_t*>(profile.name.data()),
               reinterpret_cast<const uint8_t*>(profile.name.data()) + name_len);
    return out;
}

bool sw_profile_decode(const uint8_t* data, size_t len, SWProfile& out) {
    if (!data || len < 2) return false;

    uint8_t mbti_index = data[0];
    if (mbti_index >= 16) return false;

    uint8_t name_len = data[1];
    if (static_cast<size_t>(2 + name_len) > len) return false;
    if (name_len > kMaxNameBytes) return false;

    out.mbti_index = mbti_index;
    out.name.assign(reinterpret_cast<const char*>(data + 2), name_len);
    return true;
}

const char* sw_mbti_name(uint8_t index) {
    if (index >= 16) return "";
    return kMbtiTypes[index];
}

// RSSI → distance category, calibrated for a 0–2 m contact range.
// Beyond ~2 m (RSSI ≤ -85) the peer is treated as out-of-range in
// SWBleManager and will time out naturally; sw_rssi_to_distance is only
// called for in-range readings.
//
// Approximate distances (environment-dependent):
//   very_close: < 0.5 m  (> -60 dBm)
//   near:     0.5–1.0 m  (-60 to -70 dBm)
//   medium:   1.0–1.5 m  (-70 to -78 dBm)
//   far:      1.5–2.0 m  (-78 to -85 dBm)
SWDistanceCategory sw_rssi_to_distance(int rssi) {
    if (rssi > -60) return SWDistanceCategory::very_close;
    if (rssi > -70) return SWDistanceCategory::near;
    if (rssi > -78) return SWDistanceCategory::medium;
    return SWDistanceCategory::far;
}

const char* sw_distance_name(SWDistanceCategory d) {
    switch (d) {
        case SWDistanceCategory::very_close: return "very_close";
        case SWDistanceCategory::near:       return "near";
        case SWDistanceCategory::medium:     return "medium";
        case SWDistanceCategory::far:        return "far";
    }
    return "far";
}

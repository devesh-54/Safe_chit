/// Master toggle for mock/fallback data when backend calls fail.
///
/// When `true`, READ methods return in-memory mock data on failure.
/// When `false`, READ methods rethrow the error.
///
/// WRITE methods NEVER fall back to mock regardless of this flag.
const bool kAllowMockFallback = true;

use v6.d;

# Monotonic wall-clock access for timing the simulation loop
unit module LangTest::Clock;

use NativeCall;

# C layout of struct timespec returned by clock_gettime
class Timespec is repr('CStruct') {
    has long $.tv_sec;
    has long $.tv_nsec;
}

# POSIX entry point for reading a system clock
sub clock_gettime(int32 $clock, Timespec $ts --> int32)
    is native
    is symbol('clock_gettime')
    { * }

# Injectable timer contract used by the simulator
role MonotonicClock is export {
    # Read the current monotonic time in seconds
    method now(--> Num) { ... }
}

# Real monotonic clock backed by CLOCK_MONOTONIC
class PosixClock does MonotonicClock is export {
    # Read CLOCK_MONOTONIC and combine its seconds and nanoseconds
    method now(--> Num) {
        my Timespec $ts .= new;
        clock_gettime(1, $ts);
        $ts.tv_sec.Num + $ts.tv_nsec.Num / 1_000_000_000e0;
    }
}

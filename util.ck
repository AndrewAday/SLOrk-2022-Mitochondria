// static helper fns

public class Util {  

    /* ============ Pitch/Freq ============ */
        // JI Intervals
    16./15. => static float m2;
    9./8. => static float M2;
    6./5. => static float m3;
    5.0/4 => static float M3;
    4.0/3 => static float P4;
    45.0/32.0 => static float Aug4;
    3.0/2.0 => static float P5;
    8./5. => static float m6;
    5.0/3 => static float M6;
    16.0/9.0 => static float m7;
    15.0/8 => static float M7;

    fun static float[] toChromaticScale(float tonic) {
        return [
            tonic,
            tonic * m2,
            tonic * M2,
            tonic * m3,
            tonic * M3,
            tonic * P4,
            tonic * Aug4,
            tonic * P5,
            tonic * m6,
            tonic * M6,
            tonic * m7,
            tonic * M7
        ];
    }


    /* ============ Vector Math ============ */

    /* ============ Interpolators ============ */
    fun static float lerp(float a, float b, float t) {
        return a + t * (b - a);
    }

    fun static time timeLerp(time a, time b, float t) {
        return a + t * (b - a);
    }

    fun static float invLerp(time a, time b, time c) {
        return (c-a) / (b-a);
    }

    fun static float invLerp(float a, float b, float c) {
        return (c-a) / (b-a);
    }

    // remaps c from [a,b] to range [x,y]
    fun static float remap(float a, float b, float x, float y, float c) {
        return lerp(x, y, invLerp(a,b,c));
    }

    fun static float remap(time a, time b, float x, float y, time c) {
        return lerp(x, y, invLerp(a,b,c));
    }

    fun static float clamp01(float f) {
        return Math.max(.0, Math.min(f, .99999));
    }

    fun static float lfo(float freq) {
        return Math.sin(2*pi*freq*(now/second));
    }

    /* ============ Printers ============ */
    fun static void printLerpProgress(float t) {  // t in [0, 1]
        (t * 10) $ int => int T;
        "S[" @=> string output;
        repeat(T) {
            "=" +=> output;
        }
        repeat (10-T) {
            " " +=> output;
        }
        "]E" +=> output;
        <<< output >>>;
    }
}
Util util;
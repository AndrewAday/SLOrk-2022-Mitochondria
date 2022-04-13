//--------------------------------------------------------------------
// name: twilight.ck
// desc: twilight instrument + client for laptop orchestra
//
// author: Ge Wang (ge@ccrma.stanford.edu)
// date: Spring 2013
//--------------------------------------------------------------------

// the instrument mode
1 => int TWILIGHT_MODE;
// mode enumerations
0 => int MODE_NONE;
1 => int MODE_CREAK;
2 => int MODE_ZING;
3 => int MODE_RATCHET;
4 => int MODE_DRONE;
5 => int MODE_NOTE_1;
6 => int MODE_NOTE_2;
7 => int MODE_NOTE_3;
8 => int MODE_BOOM_1;
9 => int MODE_BOOM_2;
10 => int MODE_BOOM_3;
11 => int MODE_BOOM_4;
12 => int MODE_MAX;

// max lisa voices
30 => int LISA_MAX_VOICES;
// grain duration base
10::ms => dur GRAIN_DURATION_BASE;
// grain duration (in multiples of duration base)
10 => float GRAIN_DURATION_FACTOR;
// factor relating grain duration to ramp up/down time
.5 => float GRAIN_RAMP_FACTOR;
// playback rate
1 => float GRAIN_PLAY_RATE;
// grain rate factor (0 means no change)
.05 => float GRAIN_RATE_FACTOR;
// compression factor for game trak z-pull (1 == no change)
1 => float GT_Z_COMPRESSION;
// threshold below which z has no effect
.025 => float GT_Z_DEADZONE;

// boom threshold for triggering sound
.5 => float BOOM_THRESHOLD;
// boom rate factor
.5 => float BOOM_RATE_FACTOR;
// boom rate
1 => float BOOM_PLAY_RATE;

// load file into LiSa
load( "creak-3.aiff" ) @=> LiSa @ lisaCreak;
load( "zing-1.aiff" ) @=> LiSa @ lisaZing;
load( "ratchet-1.aiff" ) @=> LiSa @ lisaRatchet;
load( "drone-1.aiff" ) @=> LiSa @ lisaDrone;

// load file for playback
snd( "impact-distant-1.aiff" ) @=> SndBuf @ sndBoom1;
snd( "impact-distant-2.aiff" ) @=> SndBuf @ sndBoom2;
snd( "impact-metallic-1.aiff" ) @=> SndBuf @ sndBoom3;
snd( "slam-terminator.aiff" ) @=> SndBuf @ sndBoom4;

// sine
TriOsc sine;
// patch it
PoleZero blocker => NRev reverb => dac;
// reverb mix
.05 => reverb.mix;
// pole location
.99 => blocker.blockZero;

// connect
sine => reverb;
sndBoom1 => reverb;
sndBoom2 => reverb;
sndBoom3 => reverb;
sndBoom4 => reverb;

// lisa reference
LiSa @ lisa;
// boom reference
SndBuf @ boom;

// set mode
mode( TWILIGHT_MODE );

// select mode
fun void mode( int which )
{
    // sanity check
    if( which < 0 && which >= MODE_MAX )
        0 => which;
    
    // set it
    which => TWILIGHT_MODE;
    
    // disconnect
    if( lisa != null ) lisa.chan(0) =< blocker;
    // if( boom != null ) boom =< reverb;
    
    // sine
    0 => sine.gain;

    // zero out
    null @=> lisa;
    // null @=> boom;
    
    // log
    <<< "NEW MODE:", which >>>;

    // check mode
    if( which == MODE_CREAK )
    {
        // set the lisa
        lisaCreak @=> lisa;
        // set parameters
        10::ms => GRAIN_DURATION_BASE;
        6 => GRAIN_DURATION_FACTOR;
        .5 => GRAIN_RAMP_FACTOR;
        1 => GRAIN_PLAY_RATE;
        .12 => GRAIN_RATE_FACTOR;
        .6 => GT_Z_COMPRESSION;
        // set reverb
        .05 => reverb.mix;
    }
    else if( which == MODE_ZING )
    {
        // set
        lisaZing @=> lisa;
        // set parameters
        10::ms => GRAIN_DURATION_BASE;
        10 => GRAIN_DURATION_FACTOR;
        .5 => GRAIN_RAMP_FACTOR;
        1 => GRAIN_PLAY_RATE;
        .05 => GRAIN_RATE_FACTOR;
        1 => GT_Z_COMPRESSION;
        // set reverb
        .05 => reverb.mix;
    }
    else if( which == MODE_RATCHET )
    {
        // set
        lisaRatchet @=> lisa;
        // set parameters
        10::ms => GRAIN_DURATION_BASE;
        6 => GRAIN_DURATION_FACTOR;
        .5 => GRAIN_RAMP_FACTOR;
        1 => GRAIN_PLAY_RATE;
        .2 => GRAIN_RATE_FACTOR;
        2 => GT_Z_COMPRESSION;
        // set reverb
        .05 => reverb.mix;
    }
    else if( which == MODE_DRONE )
    {
        // set
        lisaDrone @=> lisa;
        // set parameters
        10::ms => GRAIN_DURATION_BASE;
        15 => GRAIN_DURATION_FACTOR;
        .5 => GRAIN_RAMP_FACTOR;
        1 => GRAIN_PLAY_RATE;
        .01 => GRAIN_RATE_FACTOR;
        1 => GT_Z_COMPRESSION;
        // set reverb
        .01 => reverb.mix;
    }
    else if( which == MODE_NOTE_1 )
    {
        // set frequency
        84 => Std.mtof => sine.freq;
        // set reverb
        .1 => reverb.mix;
    }
    else if( which == MODE_NOTE_2 )
    {
        // set frequency
        79 => Std.mtof => sine.freq;
        // set reverb
        .1 => reverb.mix;
    }
    else if( which == MODE_NOTE_3 )
    {
        // set frequency
        91 => Std.mtof => sine.freq;
        // set reverb
        .1 => reverb.mix;
    }
    else if( which == MODE_BOOM_1 )
    {
        // set
        sndBoom1 @=> boom;
        // set parameters
        .5 => BOOM_RATE_FACTOR;
        // set reverb
        .05 => reverb.mix;
    }
    
    // connect
    if( lisa != null ) lisa.chan(0) => blocker;
    // if( boom != null ) boom => reverb;
}


// HID objects
Hid hi;
HidMsg msg;

// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// open joystick 0, exit on fail
if( !hi.openJoystick( device ) ) me.exit();

<<< "joystick '" + hi.name() + "' ready", "" >>>;

// data structure for gametrak
class GameTrak
{
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
}

// game track data
GameTrak gt;

// spork it
// spork ~ print();

// spork kb
spork ~ kb( 0 );
// spork network
spork ~ network();

// sporkee
fun void grain( LiSa @ lisa, dur pos, dur grainLen, dur rampUp, dur rampDown, float rate )
{
    // get a voice to use
    lisa.getVoice() => int voice;

    // if available
    if( voice > -1 )
    {
        // set rate
        lisa.rate( voice, rate );
        // set playhead
        lisa.playPos( voice, pos );
        // ramp up
        lisa.rampUp( voice, rampUp );
        // wait
        (grainLen - rampUp) => now;
        // ramp down
        lisa.rampDown( voice, rampDown );
        // wait
        rampDown => now;
    }
}

// map
fun void map()
{
    // check mode
    if( TWILIGHT_MODE >= MODE_CREAK && TWILIGHT_MODE <= MODE_DRONE )
        mapGrain();
    else if( TWILIGHT_MODE >= MODE_NOTE_1 && TWILIGHT_MODE <= MODE_NOTE_3 )
        mapNote();
    else if( TWILIGHT_MODE >= MODE_BOOM_1 && TWILIGHT_MODE <= MODE_BOOM_3 )
        mapBoom();
}

// map
fun void mapGrain()
{
    // get diff time
    // gt.currTime - gt.lastTime => dur diffTime;
    GRAIN_DURATION_BASE => dur diffTime;
    // grain length
    diffTime * GRAIN_DURATION_FACTOR => dur grainLen;
    // ramp time
    grainLen * GRAIN_RAMP_FACTOR => dur rampTime;
    // play pos
    ( gt.lastAxis[2] - GT_Z_DEADZONE ) * GT_Z_COMPRESSION + Math.random2f(0,.0001) => float pos;
    // a grain
    if( lisa != null && pos >= 0 )
        spork ~ grain( lisa, pos * lisa.duration(), grainLen, rampTime, rampTime, 
        gt.axis[0] * GRAIN_RATE_FACTOR + GRAIN_PLAY_RATE );
}

// map
fun void mapBoom()
{
    // check for threshold
    if( gt.lastAxis[0] < BOOM_THRESHOLD && gt.axis[0] >= BOOM_THRESHOLD )
        0 => boom.pos;
    
    // always map rate
    gt.axis[1] * BOOM_RATE_FACTOR + BOOM_PLAY_RATE => boom.rate;
}

// map
fun void mapNote()
{
    // play pos
    ( gt.lastAxis[2] - GT_Z_DEADZONE ) * GT_Z_COMPRESSION => float pos;

    // check
    if( pos >= 0 )
    {
        // set gain
        pos => sine.gain;
    }
    else 0 => sine.gain;
}

// print
fun void print()
{
    // time loop
    while( true )
    {
        // values
        <<< "axes:", gt.axis[0],gt.axis[1],gt.axis[2],
        gt.axis[3],gt.axis[4],gt.axis[5] >>>;
        // advance time
        100::ms => now;
    }
}

// infinite event loop
while( true )
{
    // wait on HidIn as event
    hi => now;
    
    // messages received
    while( hi.recv( msg ) )
    {
        // joystick axis motion
        if( msg.isAxisMotion() )
        {            
            // check which
            if( msg.which >= 0 && msg.which < 6 )
            {
                // check if fresh
                if( now > gt.currTime )
                {
                    // time stamp
                    gt.currTime => gt.lastTime;
                    // set
                    now => gt.currTime;
                    // map
                    map();
                }
                // save last
                gt.axis[msg.which] => gt.lastAxis[msg.which];
                // the z axes map to [0,1], others map to [-1,1]
                if( msg.which != 2 && msg.which != 5 )
                { msg.axisPosition => gt.axis[msg.which]; }
                else
                { 1 - ((msg.axisPosition + 1) / 2) => gt.axis[msg.which]; }
            }
        }
        
        // joystick button down
        else if( msg.isButtonDown() )
        {
            // <<< "joystick button", msg.which, "down" >>>;
        }
        
        // joystick button up
        else if( msg.isButtonUp() )
        {
            // <<< "joystick button", msg.which, "up" >>>;
        }
    }
}


// load file into a SndBuf
fun SndBuf snd( string filename )
{
    // sound buffer
    SndBuf buffy;
    // load it
    filename => buffy.read;
    
    // set position to end (so it doesn't play)
    buffy.samples() => buffy.pos;
    
    return buffy;
}


// load file into a LiSa
fun LiSa load( string filename )
{
    // sound buffer
    SndBuf buffy;
    // load it
    filename => buffy.read;
    
    // new LiSa
    LiSa lisa;
    // set duration
    buffy.samples()::samp => lisa.duration;
    
    // transfer values from SndBuf to LiSa
    for( 0 => int i; i < buffy.samples(); i++ )
    {
        // args are sample value and sample index
        // (dur must be integral in samples)
        lisa.valueAt( buffy.valueAt(i), i::samp );        
    }
    
    // set LiSa parameters
    lisa.play( false );
    lisa.loop( false );
    lisa.maxVoices( LISA_MAX_VOICES );
    
    return lisa;
}


// keyboard
fun void kb( int device )
{    
    // instantiate a HidIn object
    Hid hi;
    // structure to hold HID messages
    HidMsg msg;
    
    // open keyboard
    if( !hi.openKeyboard( device ) ) me.exit();
    // successful! print name of device
    <<< "server keyboard '", hi.name(), "' ready" >>>;
    
    // infinite event loop
    while( true )
    {
        // wait on event
        hi => now;
        
        // get one or more messages
        while( hi.recv( msg ) )
        {
            // check for action type
            if( msg.isButtonDown() )
            {
                // if a number
                if( msg.which >= 30 && msg.which <= 38 )
                {
                    // set the current mode
                    msg.which - 29 => int m;
                    // log
                    // <<< "CLIENT MODE:", m >>>;
                    // set
                    mode( m );
                }
            }
        }
    }
}


// receiver
fun void network()
{
    // create our OSC receiver
    OscRecv recv;
    // use port 6449
    6449 => recv.port;
    // start listening (launch thread)
    recv.listen();
    
    // create an address in the receiver, store in new variable
    recv.event( "/slork/twilight/mode, i" ) @=> OscEvent oe;
    
    // mode
    int m;
    
    // infinite event loop
    while ( true )
    {
        // wait for event to arrive
        oe => now;
        
        // grab the next message from the queue. 
        while( oe.nextMsg() != 0 )
        {
            // get mode
            oe.getInt() => m;
            // new mode
            if( m != TWILIGHT_MODE )
            {
                // set mode
                mode( m );
            }
        }
    }
}
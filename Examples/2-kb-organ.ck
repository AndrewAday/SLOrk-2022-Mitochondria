// source: https://ccrma.stanford.edu/courses/220b/ck/2-kb-organ.ck

// HID
Hid hi;
HidMsg msg;

// which keyboard
1 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// open keyboard (get device number from command line)
if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;

// patch
BeeThree organ => NRev r => Echo e => Echo e2 => dac;
// Rhodey organ => JCRev r => Echo e => Echo e2 => dac;
organ.help();
r => dac;  // un-echoed signal

// set delays
// 2040::ms => e.max => e.delay;
// 4080::ms => e2.max => e2.delay;

240::ms => e.max => e.delay;
480::ms => e2.max => e2.delay;

// set gains
.6 => e.gain;
.51 => e2.gain;
1 => r.mix;
0 => organ.gain;

// .6 => e.gain;
// .3 => e2.gain;
// .1 => r.mix;
// 0 => organ.gain;

// infinite event loop
while( true )
{
    // wait for event
    hi => now;

    // get message
    while( hi.recv( msg ) )
    {
        <<< msg.which >>>;
        // check
        if( msg.isButtonDown() )
        {
            Std.mtof( msg.which + 45 ) => float freq;
            if( freq > 20000 ) continue;

            freq => organ.freq;
            .5 => organ.gain;
            1 => organ.noteOn;

            80::ms => now;
        }
        else
        {
            0 => organ.noteOff;
        }
    }
}

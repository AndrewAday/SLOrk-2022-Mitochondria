// destination host name
["localhost"] @=> string hostnames[];
// destination port number
6449 => int port;

// check command line
// if( me.args() ) me.arg(0) => hostname;
// if( me.args() > 1 ) me.arg(1) => Std.atoi => port;

// sender object
1 => int NUM_RECEIVERS;
OscOut xmits[NUM_RECEIVERS];

// aim the transmitter at destination
for (0 => int i; i < NUM_RECEIVERS; i++) {
    xmits[i].dest( hostnames[i], port );
}


// spork sending loops, one for each message type
TaikoDrummer.bpm_to_qt_note(86) => dur qt_note;

spork ~ send_beat("/taiko/whole_note", 4*qt_note);
spork ~ send_beat("/taiko/qt_note", qt_note);
spork ~ send_beat("/taiko/qt_note_triplet", (2.0/3.0) * qt_note);
spork ~ send_beat("/taiko/qt_note_quintuplet", (2.0/5.0) * qt_note);

// keep allive
while( true ) 1::second => now;

fun void send_beat(string msg, dur beat_dur)
{
    // infinite time loop
    while( true )
    {
        for (0 => int i; i < NUM_RECEIVERS; i++) {
            // start the message...
            xmits[i].start( msg );
            
            // add int argument
            // Math.random2( 30, 80 ) => xmit.add;
            // add float argument
            // Math.random2f( .1, .5 ) => xmit.add;
            
            // send it
            xmits[i].send();
            
            // advance time
            beat_dur => now;
        }
    }
}
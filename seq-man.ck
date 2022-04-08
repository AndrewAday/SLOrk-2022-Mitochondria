/*
Sequence Manipulator

Mutations (in order of operation):


Replicate(N): copy motif N times
copy(-N ... N): copy the prev/next N notes and insert at idx
sub(-N ... N): remove the prev/next N notes from idx
add(N): add N notes at idx
Extract(-N .... N): extract the prev/next N notes from idx


TODO: a way to add/remove allowed scale degrees

*/


public class SeqMan {
  0 => int idx; // TODO: wrap around
  1 => int repl_n;
  int copy_n;
  int sub_n;
  int add_n;
  int extr_n;
  int should_rev;

  /* [55., 60., 62., 63., 65., 67.] @=> float scale[]; // allowed notes */
  [2/3., 1., 9/8., 6/5., 4/3., 3/2.] @=> float scale[]; // allowed notes
  float seq[];

  fun void init(float seq[], float scale[]) {
    seq @=> this.seq;
    scale @=> this.scale;
  }

  fun void init(float seq[]) {
    seq @=> this.seq;
  }

  fun void replicate(int n) {
    if (n <= 1) { return; }

    float new_seq[seq.cap() * n];
    for (int i; i < new_seq.cap(); i++) {
      this.seq[i % this.seq.cap()] => new_seq[i];
    }
    new_seq @=> this.seq;
  }

  fun void copy(int n) {
    if (n == 0) { return; }

    float new_seq[seq.cap() + Std.abs(n)];
    int beg; int end;
    if (n < 0) {
      this.idx + n => beg; this.idx => end;
    } else {
      this.idx => beg; this.idx + n => end;
    }

    int i;
    for (; i < this.idx; i++) {
      this.seq[i] => new_seq[i];
    }

    // copy sebsequence
    for (beg => int j; j < end; j++) {
      this.seq[j % this.seq.cap()] => new_seq[i++];
    }

    for (this.idx => int k; k < this.seq.cap(); k++) {
      this.seq[k] => new_seq[i++];
    }

    new_seq @=> this.seq;
  }

  fun void sub(int n) {
    if (n == 0) { return; }
    float new_seq[this.seq.cap() - Std.abs(n)];
    int beg; int end;
    if (n < 0) {
      this.idx + n => beg; this.idx => end;
    } else {
      this.idx => beg; this.idx + n => end;
    }

    int i;
    for (; i < beg; i++) {
      this.seq[i] => new_seq[i];
    }
    for (end => int j; j < this.seq.cap(); j++) {
      this.seq[j] => new_seq[i++];
    }

    new_seq @=> this.seq;
  }

  fun void add(int n) {
    if (n == 0) { return; }
    float new_seq[this.seq.cap() + n];

    int i;
    for (; i < this.idx; i++) {
      this.seq[i] => new_seq[i];
    }

    for (int j; j < n; j++) {
      this.scale[Math.random2(0, this.scale.cap()-1)] => new_seq[i++];
    }

    for (this.idx => int k; k < this.seq.cap(); k++) {
      this.seq[k] => new_seq[i++];
    }

    new_seq @=> this.seq;
  }

  fun void extract(int n) {
    if (n==0) { return; }
    float new_seq[n];

    int beg; int end;
    if (n < 0) {
      this.idx + n => beg; this.idx => end;
    } else {
      this.idx => beg; this.idx + n => end;
    }

    int i;
    for (beg => int j; j < end; j++) {
      this.seq[j % this.seq.cap()] => new_seq[i++];
    }

    new_seq @=> this.seq;
  }

  fun void rev() {
    float new_seq[this.seq.cap()];
    for (this.seq.cap() - 1 => int i; i >= 0; i--) {
      this.seq[i] => new_seq[this.seq.cap()-1-i];
    }
    new_seq @=> this.seq;
  }

  fun float[] manipulate() {
    this.replicate(this.repl_n);
    this.copy(this.copy_n);
    this.sub(this.sub_n);
    this.extract(this.extr_n);
    this.add(this.add_n);
    if (should_rev) {
      this.rev();
    }

    return this.seq;
  }

  // Reset the mutation bank
  fun void reset() {
    1 => this.repl_n;
    0 => this.idx => this.copy_n => this.sub_n => this.add_n => this.extr_n => this.should_rev;
  }

  fun string get_idx_str() {
    "" => string ret;
    " [~^~] " => string marker;
    for (int i; i < this.seq.cap(); i++) {
      if (i == this.idx) {
        marker +=> ret;
      }
      (" " + this.seq[i] + " ") +=> ret;
    }
    if (this.idx == this.seq.cap()) {
      marker +=> ret;
    }
    return ret;
  }

  fun void print_state() {
    <<<
    /* "len: ", this.seq.cap(), " | ", */
    /* "idx: ", this.idx , " | ", */
    " replicate: ", this.repl_n-1, " | ",
    " copy: ", this.copy_n, " | ",
    " sub: ", this.sub_n, " | ",
    " add: ", this.add_n, " | ",
    " extract: ", this.extr_n, " | ",
    " rev: ", this.should_rev, " | ">>>;
    <<< get_idx_str() >>>;
    <<< "=============================================================" >>>;
  }

  /* interface controls */
  /* fun void mod_repl(int n) {
    if (n < 0)
  } */
}

fun void print_arr(float seq[]) {
  "" => string ret;
  for (int i; i < seq.cap(); i++) {
    " " + seq[i] + " " +=> ret;
  }
  <<< ret >>>;
}


fun void unit_test() {


[1.,2.,3.,4.,5.] @=> float seq[];
SeqMan seqman;
seqman.init(seq);

/* print_arr(seqman.seq); */
2 => seqman.repl_n;
seqman.manipulate();
/* print_arr(seqman.seq); */


seqman.init(seq);
seqman.reset();
seqman.print_state();


/* print_arr(seqman.seq); */
3 => seqman.idx;
1 => seqman.copy_n;
seqman.print_state();
seqman.manipulate();
/* print_arr(seqman.seq); */

seqman.init(seq);
seqman.reset();
seqman.print_state();

3 => seqman.idx;
-2=> seqman.sub_n;
seqman.print_state();
seqman.manipulate();
/* print_arr(seqman.seq); */
seqman.print_state();

seqman.init(seq);
seqman.reset();
seqman.print_state();

// test add
1 => seqman.idx;
3 => seqman.add_n;
seqman.print_state();
seqman.manipulate();
/* print_arr(seqman.seq); */
}

/* unit_test(); */

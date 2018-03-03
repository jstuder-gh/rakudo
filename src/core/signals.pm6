my enum Signal ( |nqp::getsignals() );

proto sub signal(|) {*}
multi sub signal(Signal $signal, *@signals, :$scheduler = $*SCHEDULER) {

    if @signals.grep( { !nqp::istype($_,Signal) } ).list -> @invalid {
        die "Found invalid signals: {@invalid}";
    }
    @signals.unshift: $signal;
    @signals .= unique;

    my class SignalCancellation is repr('AsyncTask') { }
    Supply.merge( @signals.map(-> $sig {
        my $s = Supplier.new;
        nqp::signal($scheduler.queue(:hint-time-sensitive),
            -> $signum { $s.emit($signum) },
            nqp::unbox_i($sig),
            SignalCancellation);
        $s.Supply
    }) );
}

# vim: ft=perl6 expandtab sw=4

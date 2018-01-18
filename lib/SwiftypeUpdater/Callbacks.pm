package SwiftypeUpdater::Callbacks;

use strict;
use v5.10;
use Data::Printer;
use MT::TheSchwartz;
use TheSchwartz::Job;

sub build_file {
    my ( $cb, %args ) = @_;
    my $fi            = $args{file_info};
    my $ctx           = $args{context};

    return if $args{file} =~ m{\.xml$};

    MT::TheSchwartz->insert(
        TheSchwartz::Job->new(
            funcname  => 'SwiftypeUpdater::Worker::Update',
            uniqkey   => $fi->id,
            priority  => 1, # Lower than all default publishing priorities
            coalesce  => $$ . ':' . ( time - ( time % 10 ) ),
            arg       => $ctx->invoke_handler( 'canonicalurl' ),
            # run_after => time + (5 * 60),
        )
    );
    return;
}

sub post_delete {
    my ( $cb, $file, $at, $entry ) = @_;
    # my $d = { file => $file, at => $at, entry => $entry, permalink => $entry->permalink }; p $d;

    return unless $entry;

    MT::TheSchwartz->insert(
        TheSchwartz::Job->new(
            funcname  => 'SwiftypeUpdater::Worker::Update',
            uniqkey   => join( ':', 'delete', $at, $entry->id ),
            priority  => 1, # Lower than all default publishing priorities
            coalesce  => $$ . ':' . ( time - ( time % 10 ) ),
            arg       => $entry->permalink,
            # run_after => time + (5 * 60),
        )
    );
    return;
}

1;

__END__

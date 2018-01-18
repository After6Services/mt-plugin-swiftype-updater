package SwiftypeUpdater::Callbacks;

use strict;
use v5.10;
use Data::Printer;

sub build_file {
    my ( $cb, %args ) = @_;
    my $fi            = $args{file_info};
    my $ctx           = $args{context};

    # See TheSchwartz::Job FIELDS in POD
    require MT::TheSchwartz;
    require TheSchwartz::Job;
    MT::TheSchwartz->insert(
        TheSchwartz::Job->new(
            funcname  => 'SwiftypeUpdater::Worker::Update',
            uniqkey   => $fi->id,
            priority  => 11, # Higher than all default publishing priorities
            coalesce  => $$ . ':' . ( time - ( time % 10 ) ),
            arg       => $ctx->invoke_handler( 'canonicalurl' ),
            # run_after => time + (5 * 60),
        )
    );
    return;
}

# post_delete_archive_file
# MT->run_callbacks( 'post_delete_archive_file', $file, $at, $entry );
sub post_delete {
    my ( $cb, $file, $at, $entry ) = @_;
    my $arg = { file => $file, at => $at, entry => $entry };
    print STDERR "DELETED FILE: ".p($arg);

    return;

    # See TheSchwartz::Job FIELDS in POD
    require MT::TheSchwartz;
    require TheSchwartz::Job;
    MT::TheSchwartz->insert(
        TheSchwartz::Job->new(
            funcname  => 'SwiftypeUpdater::Worker::Update',
            uniqkey   => join( ':', 'delete',
                                    $at->entry_class, $entry->id ),
            priority  => 11, # Higher than all default publishing priorities
            coalesce  => $$ . ':' . ( time - ( time % 10 ) ),
            arg       => $arg,
            # run_after => time + (5 * 60),
        )
    );
    return;
}

1;

__END__

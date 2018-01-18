package SwiftypeUpdater::Worker::Update;

use strict;
use v5.10;
use TheSchwartz::Job;
use MT::TheSchwartz;

sub grab_for    { 60 }
sub max_retries { 100000 }
sub retry_delay { 60 }

sub work {
    my $class                = shift;
    my TheSchwartz::Job $job = shift;
    my $mt                   = MT->instance;

    my @jobs = _find_coalescing_jobs( $job );

    my $cfg  = MT::ConfigMgr->instance;
    my $st   = SwiftypeUpdater::API->new(
        endpoint    => $cfg->SwiftypeAPIEndpoint,
        key         => $cfg->SwiftypeAPIKey,
        engine_slug => $cfg->SwiftypeEngineSlug,
        domain_id   => $cfg->SwiftypeDomainID,
        timeout     => $cfg->SwiftypeTimeout,
        useragent   => MT->instance->new_ua({
                        timeout => $cfg->SwiftypeTimeout }),
        debug       => $cfg->SwiftypeDebug,
    );

    my @urls;
    foreach my $job ( @jobs ) {
        my ( $method, $url ) = _url_from_job( $job );
        next unless $url;

        if ( $st->$method( $url )) {
            $job->completed();
        }
        else {
            $job->failed( 'Error during recrawl: ' . $st->errstr );
        }
    }
}

sub _find_coalescing_jobs {
    my $job  = shift;
    my @jobs = ( $job );
    if ( my $key = $job->coalesce ) {
        my $ts   = MT::TheSchwartz->instance;
        my $func = $ts->can('find_job_with_coalescing_value');
        while ( my $job = $func->( $ts, __PACKAGE__, $key )) {
            push @jobs, $job;
        }
    }
    return @jobs
}

sub _url_from_job {
    my $job = shift;
    my ( $method, $url );
    if ( $job->uniqkey =~ m{^delete} ) {
        $method = 'destroy_url';
        my $arg       = $job->arg;
        my $file      = $arg->{file};
        my $entry     = $arg->{entry};
        my $blog      = $entry->blog;
        my $permalink = $entry->permalink;
        ...;
    }
    else {
        $method = 'crawl_url';
        $url = $job->arg;
        unless ( $url ) {
            my $fi = MT->model('fileinfo')->load( $job->uniqkey )
                or $job->completed();
            if ( $fi and $url = _url_from_fileinfo( $fi )) {
                $job->permanent_failure( "No URL for file: "
                                         . $fi->file_path );
            }
        }
    }
    return $url;
}

sub _url_from_fileinfo {
    my $fi        = shift or return;
    my $blog      = MT->model('blog')->load( $fi->blog_id );
    my $base_url  = $blog->site_url;
    $base_url    .= '/' unless $base_url =~ m|/$|;
    my $url       = $base_url . $fi->url;
    $url          =~ s{(?<!:)//+}{/}g;
    MT::TheSchwartz->debug(
        $url ? "Constructed URL: $url"
             : "Warning: couldn't locate URL for file: " . $fi->file_path
    );
    return $url;
}

1;

__END__

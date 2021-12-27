package SwiftypeUpdater::API;

use v5.10;
use Moo;
use strictures 2;
use namespace::clean;
use REST::Client;
use URI;
use JSON;
use Encode qw(encode_utf8);
use Data::Printer;
use HTTP::Headers::Fast; #Added by Dave Aiello, 08/18/2021

extends 'MT::ErrorHandler';

has [qw( key engine_slug )] => (
    is => 'lazy',
    isa => sub {
        die "'$_[0]' is not a string"
            unless defined($_[0]) && length($_[0]) && $_[0] =~ m{[A-Za-z]+};
    },
    default => sub { '' },
);

has 'endpoint' => (
    is      => 'lazy',
    isa     => sub {
        die "$_[0] is not an endpoint URL"
            unless ref($_[0]) && $_[0]->isa('URI::http');
    },
    coerce  => sub { URI->new( $_[0] ) },
    default => sub { URI->new('https://api.swiftype.com/api/v1') }
);

has 'timeout' => (
    is      => 'lazy',
    default => sub { 10 },
);

has 'useragent' => (
    is      => 'lazy',
    default => sub { 'LWP::UserAgent' },
    coerce  => sub { ref($_[0]) ? $_[0] : $_[0]->new },
);

has 'domain_id' => (
    is      => 'lazy',
);

has 'client' => (
    is  => 'lazy',
    isa => sub {
      die "$_[0] is not REST::Client instance"
          unless ref($_[0]) && $_[0]->isa('REST::Client');
    },
);

has 'debug' => (
    is      => 'rw',
    default => sub { 0 },
);

sub _build_client {
    my $self   = shift;
    my $client = REST::Client->new({
        host      => $self->endpoint,
        timeout   => $self->timeout,
        useragent => $self->useragent,
    });

    $self->debug
        and say STDERR "Created REST::Client instance ".np($client);

    return $client;
}

sub _build_domain_id {
    my $self = shift;
    my $path = sprintf( '/engines/%s/domains.json?auth_token=%s',
                            $self->engine_slug, $self->key );
    my $domain = decode_json(
                $self->client->GET($path)->responseContent() );
    return $domain->[0]{id};
}

sub crawl_url {
    my $self   = shift;
    my $url    = URI->new(+shift);
    unless ( $url->isa( 'URI::http' )) {
        my $msg = "Invalid URL in crawl_url: '$url'";
        warn $msg;
        return $self->error($msg);
    }

    my $path   = sprintf(
        '/engines/%s/domains/%s/crawl_url.json'
        , $self->engine_slug
        , $self->domain_id
    );

    my $data         = { url => $url->as_string,
                         auth_token => $self->key }; # Key must be passed as auth_token, per https://swiftype.com/documentation/site-search/api-crawler-operations#crawl-url .
    my $encoded_data = encode_utf8(encode_json($data));

    my $h = HTTP::Headers::Fast->new;
    # $h->authorization_basic( $self->key ); Key cannot be passed via authentication_basic header, per https://swiftype.com/documentation/site-search/api-crawler-operations#crawl-url .
    $h->content_type('application/json; charset=UTF-8');
    my %headers = ();
    %headers = $h->flatten;

    if ( my $db = $self->debug ) {
        say STDERR "crawl_url API call: PUT $path with body "
                    .np($data);
        p %headers;
        return 1 if $db =~ m{NoCalls(\b|Crawl)}i;
    }

    my $response = $self->client->PUT( $path, $encoded_data, \%headers );
    $self->debug and say STDERR $response->responseContent();

    return 1 if $response->responseCode() =~ m{2\d\d};

    my $msg
        = sprintf "ERROR: crawl_url of %s failed with %s error: %s\n",
            $url->as_string,
            $response->responseCode(),
            $response->responseContent();
    warn $msg;
    return $self->error( $msg );
}

sub destroy_url {
    my $self   = shift;
    my $url    = URI->new(+shift);
    unless ( $url->isa( 'URI::http' )) {
        my $msg = "Invalid URL in destroy_url: '$url'";
        warn $msg;
        return $self->error($msg);
    }

    my $path   = sprintf(
        '/engines/%s/document_types/page/documents/destroy_url'
        .'?url=%s'
        , $self->engine_slug
        , $url->as_string
    );

    my $h = HTTP::Headers::Fast->new;
    $h->authorization_basic( $self->key );
    my $headers = $h->flatten; # Trying $headers instead of %headers, per https://stackoverflow.com/questions/17298127/reference-found-where-even-sized-list-expected-in-perl-possible-pass-by-refere, Dave Aiello, 08/19/2021

    if ( my $db = $self->debug ) {
        say STDERR "destroy_url API call: DELETE $path";
        p $headers; # Trying $headers instead of %headers, per https://stackoverflow.com/questions/17298127/reference-found-where-even-sized-list-expected-in-perl-possible-pass-by-refere, Dave Aiello, 08/19/2021
        return 1 if $db =~ m{NoCalls(\b|Destroy)}i;
    }

    my $response = $self->client->DELETE($path, @{$headers});
    $self->debug and say STDERR $response->responseContent();

    return 1 if $response->responseCode() =~ m{2\d\d};

    my $msg = sprintf "ERROR: destroy_url of %s failed with %s error: %s\n",
                    $url->as_string,
                    $response->responseCode(),
                    $response->responseContent();
    warn $msg;
    return $self->error( $msg );
}

1;

__END__

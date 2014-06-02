use Mojo::Base -strict;

BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
}

use Test::More;
use Mojolicious::Lite;
use Scalar::Util 'weaken';
use Test::Mojo;

plugin plack_middleware => [];

# Stream multipart uploads into cache
my %cache;
hook after_build_tx => sub {
  my $tx = shift;

  weaken $tx;
  $tx->req->content->on(
    upgrade => sub {
      my ($single, $multi) = @_;

      return unless $tx->req->url->path->contains('/upload');

      my $id = $tx->req->url->query->param('id');
      $multi->on(
        part => sub {
          my ($multi, $single) = @_;
          $single->on(
            body => sub {
              my $single = shift;
              return unless $single->headers->content_disposition =~ /my_file/;
              $single->unsubscribe('read');
              $single->on(read => sub { $cache{$id} .= pop });
            }
          );
        }
      );
    }
  );
};

post '/upload' => sub {
  my $self = shift;
  my $id   = $self->param('id');
  $self->render(data => $cache{$id});
};

get '/download' => sub {
  my $self = shift;
  $self->render(data => $cache{$self->param('id')});
};

my $t = Test::Mojo->new;

# Small upload
$t->post_ok('/upload?id=23' => form => {my_file => {content => 'whatever'}})
  ->status_is(200)->content_is('whatever');

# Small download
$t->get_ok('/download?id=23')->status_is(200)->content_is('whatever');

# Big upload
$t->post_ok(
  '/upload?id=24' => form => {my_file => {content => '1234' x 131072}})
  ->status_is(200)->content_is('1234' x 131072);

# Big download
$t->get_ok('/download?id=24')->status_is(200)->content_is('1234' x 131072);

# Small download again
$t->get_ok('/download?id=23')->status_is(200)->content_is('whatever');

done_testing();

package Template_Basic;
use strict;
use warnings;
use base 'Test::Class';
use Test::More;
use Test::Mojo;
use utf8;

    my $backup = $ENV{MOJO_MODE} || '';
    
    __PACKAGE__->runtests;
    
    sub single_filter : Test(8) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('SomeApp');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 18)
			->content_is('original[filtered]');
        $t->get_ok('/css.css')
			->status_is(200)
			->header_is('Content-length', 13)
			->content_is('css[filtered]');
    }
    
    sub multipart : Test(1) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('SomeApp');
		local $SIG{ALRM} = sub { die "timeout\n" }; alarm 2;
		$t->tx($t->ua->get('/index',
			{'Content-Type' => 'multipart/form-data; boundary="abcdefg"'},
			"\x0d\x0a\x0d\x0acontent\x0d\x0a--abcdefg--\x0d\x0a")
		);
		$t->content_is('original[filtered]');
    }
		{
			package SomeApp;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
					'TestFilter'
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
	
    sub dual_filter : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('SomeApp2');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 29)
			->content_is('original[filtered2][filtered]');
    }
	    {
			package SomeApp2;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
					'TestFilter',
					'TestFilter2',
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
    
    sub with_args : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('SomeApp3');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 13)
			->content_is('original[aaa]');
    }
		{
			package SomeApp3;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
					'TestFilter3' => {tag => 'aaa'},
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
	
    sub body_grows_largely : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('GrowLarge');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 100001)
			->content_like(qr/890$/);
    }
		{
			package GrowLarge;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
					'GrowLargeFilter',
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('1');
				});
			}
		}
	
	sub HeadModified : Test(5) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('HeadModified');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-Type', 'text/html;charset=Shift_JIS')
			->header_is('Content-length', 6)
			->content_is('日本語');
	}
		{
			package HeadModified;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
					'ForceCharset', {charset => 'Shift_JIS'}
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('日本語');
				});
			}
		}
	
	sub enable_if_false : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('EnableIfFalse');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 8)
			->content_is('original');
	}
		{
			package EnableIfFalse;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
					'TestFilter', sub {0}
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
	
	sub enable_if_true : Test(5) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('EnableIfTrue');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 18)
			->content_is('original[filtered]');
	}
		{
			package EnableIfTrue;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use lib 't/lib';
			use Scalar::Util;
			use Test::More;
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
					'TestFilter', sub {
						ok($_[0]->isa('Mojolicious::Controller'), 'cb gets controller'); 1
					}, {
						'arg1' => 'a',
					}
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
	
	sub auth : Test(8) {
        $ENV{MOJO_MODE} = 'production';
		
        my $t = Test::Mojo->new('AppRejected');
        $t->get_ok('/index')
			->status_is(401)
			->header_is('Content-length', 22)
			->content_is('Authorization required');
		
        my $t2 = Test::Mojo->new('AppRejected');
        $t2->get_ok('/index', {Authorization => "Basic dXNlcjpwYXNz"})
			->status_is(200)
			->header_is('Content-length', 8)
			->content_is('original');
	}
		{
			package AppRejected;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use lib 't/lib';
			use Scalar::Util;
			use Test::More;
			
			sub startup {
				my $self = shift;
				
				$self->plugin(plack_middleware => ["Auth::Basic", {authenticator => sub {1}}]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
	
    END {
        $ENV{MOJO_MODE} = $backup;
    }
	
	package Plack::Middleware::TestFilter;
	use strict;
	use warnings;
	use base qw( Plack::Middleware );
	
	sub call {
		
		my $self = shift;
		my $res = $self->app->(@_);
		$self->response_cb($res, sub {
			return sub {
				if (my $chunk = shift) {
					return $chunk. '[filtered]';
				}
			};
			$res;
		});
	}
	
	package Plack::Middleware::TestFilter2;
	use strict;
	use warnings;
	use base qw( Plack::Middleware );
	
	sub call {
		
		my $self = shift;
		my $res = $self->app->(@_);
		$self->response_cb($res, sub {
			return sub {
				if (my $chunk = shift) {
					return $chunk. '[filtered2]';
				}
			};
			$res;
		});
	}
	
	package Plack::Middleware::TestFilter3;
	use strict;
	use warnings;
	use base qw( Plack::Middleware );
	
	sub call {
		
		my $self = shift;
		my $res = $self->app->(@_);
		$self->response_cb($res, sub {
			return sub {
				if (my $chunk = shift) {
					return $chunk. "[$self->{tag}]";
				}
			};
			$res;
		});
	}
	
	package Plack::Middleware::GrowLargeFilter;
	use strict;
	use warnings;
	use base qw( Plack::Middleware );
	
	sub call {
		
		my $self = shift;
		my $res = $self->app->(@_);
		$self->response_cb($res, sub {
			return sub {
				if (my $chunk = shift) {
					return $chunk. ("1234567890" x 10000);
				}
			};
			$res;
		});
	}

	package Plack::Middleware::ForceCharset;
	use strict;
	use warnings;
	use 5.008_001;
	use parent qw(Plack::Middleware);
	use Plack::Util;
	use Plack::Util::Accessor qw(charset);
	use Encode;
	
	our $VERSION = '0.02';
		
		sub call {
			my ($self, $env) = @_;
			$self->response_cb($self->app->($env), sub {
				my $res = shift;
				my $h = Plack::Util::headers($res->[1]);
				my $charset_from = 'UTF-8';
				my $charset_to = $self->charset;
				my $ct = $h->get('Content-Type');
				if ($ct =~ s{;?\s*charset=([^;\$]+)}{}) {
					$charset_from = $1;
				}
				if ($ct =~ qr{^text/(html|plain)}) {
					$h->set('Content-Type', $ct. ';charset='. $charset_to);
				}
				my $fixed_body = [];
				Plack::Util::foreach($res->[2], sub {
					Encode::from_to($_[0], $charset_from, $charset_to);
					push @$fixed_body, $_[0];
				});
				$res->[2] = $fixed_body;
				$h->set('Content-Length', length $fixed_body);
				return $res;
			});
		}
	
	package Plack::Middleware::Auth::Basic;
	use strict;
	use parent qw(Plack::Middleware);
	use Plack::Util::Accessor qw( realm authenticator );
	use Scalar::Util;
	use MIME::Base64;
		
		sub prepare_app {
			my $self = shift;
		
			my $auth = $self->authenticator or die 'authenticator is not set';
			if (Scalar::Util::blessed($auth) && $auth->can('authenticate')) {
				$self->authenticator(sub { $auth->authenticate(@_[0,1]) }); # because Authen::Simple barfs on 3 params
			} elsif (ref $auth ne 'CODE') {
				die 'authenticator should be a code reference or an object that responds to authenticate()';
			}
		}
		
		sub call {
			my($self, $env) = @_;
		
			my $auth = $env->{HTTP_AUTHORIZATION}
				or return $self->unauthorized;
			
			if ($auth =~ /^Basic (.*)$/) {
				my($user, $pass) = split /:/, (MIME::Base64::decode($1) || ":");
				$pass = '' unless defined $pass;
				if ($self->authenticator->($user, $pass, $env)) {
					$env->{REMOTE_USER} = $user;
					return $self->app->($env);
				}
			}
		
			return $self->unauthorized;
		}
		
		sub unauthorized {
			my $self = shift;
			my $body = 'Authorization required';
			return [
				401,
				[ 'Content-Type' => 'text/plain',
				  'Content-Length' => length $body,
				  'WWW-Authenticate' => 'Basic realm="' . ($self->realm || "restricted area") . '"' ],
				[ $body ],
			];
		}
		
		1;

__END__

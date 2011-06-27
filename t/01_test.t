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
        my $t = Test::Mojo->new(app => 'SomeApp');
        $t->get_ok('/index')
			->status_is(200);
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
					'TestFilter', sub {die 'hogehoge'}
				]);
				
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

__END__

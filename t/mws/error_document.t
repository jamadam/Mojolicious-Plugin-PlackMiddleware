package Template_Basic;
use strict;
use warnings;
use base 'Test::Class';
use Test::More;
use Test::Mojo;
use utf8;

    my $backup = $ENV{MOJO_MODE} || '';
    
    __PACKAGE__->runtests;
    
    sub single_filter : Test(6) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('SomeApp');
        $t->get_ok('/status/500.html')
			->status_is(500)
			->content_like(qr'fancy 500');
        $t->get_ok('/status/404.html')
			->status_is(404)
			->content_like(qr'fancy 404');
    }
		{
			package SomeApp;
			use strict;
			use warnings;
			use base 'Mojolicious';
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
					ErrorDocument => {
						500 => "$FindBin::Bin/errors/500.html"
					},
					ErrorDocument => {
						404 => "/errors/404.html",
						subrequest => 1,
					},
					Static => {
						path => qr{^/errors},
						root => $FindBin::Bin
					},
				]);
				
				$self->routes->route('/*')->to(cb => sub{
					my $c = shift;
					my $status = ($c->req->url->path =~ m!status/(\d+)!)[0] || 200;
					$c->render_text("Error: $status");
					$c->rendered($status);
				});
			}
		}
	
    END {
        $ENV{MOJO_MODE} = $backup;
    }

1;

__END__

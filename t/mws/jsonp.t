package Template_Basic;
use strict;
use warnings;
use base 'Test::Class';
use Test::More;
use Test::Mojo;
use utf8;

    my $backup = $ENV{MOJO_MODE} || '';
    
    __PACKAGE__->runtests;
    
    sub single_filter : Test(16) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new('SomeApp');
        $t->get_ok('/hash')
			->status_is(200)
			->header_is('Content-Type', 'application/json')
			->content_is(q({"foo":"bar"}));
        $t->get_ok('/hash?json.p=foo')
			->status_is(200)
			->header_is('Content-Type', 'text/javascript')
			->content_is(q(foo({"foo":"bar"})));
        $t->get_ok('/array')
			->status_is(200)
			->header_is('Content-Type', 'application/json')
			->content_is(q(["hoo","bar"]));
        $t->get_ok('/array?json.p=foo')
			->status_is(200)
			->header_is('Content-Type', 'text/javascript')
			->content_is(q(foo(["hoo","bar"])));
    }
		{
			package SomeApp;
			use strict;
			use warnings;
			use base 'Mojolicious';
			
			sub startup {
				my $self = shift;
				
				$self->plugin('plack_middleware', [
                    JSONP => {callback_key => 'json.p'},
				]);
				
				$self->routes->route('/hash')->to(cb => sub{
                    my $json = {foo => 'bar'};
					$_[0]->render_json($json);
				});
				$self->routes->route('/array')->to(cb => sub{
                    my $json = ['hoo', 'bar'];
					$_[0]->render_json($json);
				});
			}
		}
	
    END {
        $ENV{MOJO_MODE} = $backup;
    }

1;

__END__

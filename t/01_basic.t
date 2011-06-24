package Template_Basic;
use strict;
use warnings;
use base 'Test::Class';
use Test::More;
use Test::Mojo;
use MojoX::Util::ResponseFilter;
use utf8;

    my $backup = $ENV{MOJO_MODE} || '';
    
    __PACKAGE__->runtests;
    
    sub single_filter : Test(8) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'SomeApp');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 18)
			->content_is('original[filtered]');
        $t->get_ok('/css.css')
			->status_is(200)
			->header_is('Content-length', 13)
			->content_is('css[filtered]');
    }
		{
			package SomeApp;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use MojoX::Util::ResponseFilter 'enable';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				enable($self, [
					'TestFilter',
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
	
    sub dual_filter : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'SomeApp2');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 29)
			->content_is('original[filtered][filtered2]');
    }
	    {
			package SomeApp2;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use MojoX::Util::ResponseFilter 'enable';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				enable($self, [
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
        my $t = Test::Mojo->new(app => 'SomeApp3');
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
			use MojoX::Util::ResponseFilter 'enable';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				enable($self, [
					'TestFilter3' => [tag => 'aaa'],
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
	
    sub body_grows_largely : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'GrowLarge');
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
			use MojoX::Util::ResponseFilter 'enable';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				enable($self, [
					'GrowLargeFilter',
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('1');
				});
			}
		}
	
	sub HeadModified : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'HeadModified');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-Type', 'text/html;charset=Shift_JIS')
			->content_is('日本語');
	}
		{
			package HeadModified;
			use strict;
			use warnings;
			use base 'Mojolicious';
			use MojoX::Util::ResponseFilter 'enable';
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				enable($self, [
					'ForceCharset', [charset => 'Shift_JIS']
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('日本語');
				});
			}
		}
	
	sub enable_if_false : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'EnableIfFalse');
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
			use MojoX::Util::ResponseFilter qw(enable enable_if);
			use lib 't/lib';
			
			sub startup {
				my $self = shift;
				
				enable_if($self, sub {0}, [
					'TestFilter',
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
	
	sub enable_if_true : Test(5) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'EnableIfTrue');
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
			use MojoX::Util::ResponseFilter qw(enable enable_if);
			use lib 't/lib';
			use Scalar::Util;
			use Test::More;
			
			sub startup {
				my $self = shift;
				
				enable_if($self, sub {
						ok($_[0]->isa('Mojolicious::Controller'), 'cb gets controller');
						1;
					}, [
					'TestFilter',
				]);
				
				$self->routes->route('/index')->to(cb => sub{
					$_[0]->render_text('original');
				});
			}
		}
    
    END {
        $ENV{MOJO_MODE} = $backup;
    }

__END__

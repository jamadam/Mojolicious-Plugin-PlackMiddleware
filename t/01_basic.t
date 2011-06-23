package Template_Basic;
use strict;
use warnings;
use base 'Test::Class';
use Test::More;
use Test::Mojo;
use MojoX::Util::BodyFilter;
use utf8;

    my $backup = $ENV{MOJO_MODE} || '';
    
    __PACKAGE__->runtests;
    
    sub single_filter : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'SomeApp');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 18)
			->content_is('original[filtered]');
    }
    
    sub dual_filter : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'SomeApp2');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 29)
			->content_is('original[filtered][filtered2]');
    }
    
    sub with_args : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'SomeApp3');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 13)
			->content_is('original[aaa]');
    }
    
    sub body_grows_largely : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'GrowLarge');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-length', 100001)
			->content_like(qr/890$/);
    }
	
	sub HeadModified : Test(4) {
        $ENV{MOJO_MODE} = 'production';
        my $t = Test::Mojo->new(app => 'HeadModified');
        $t->get_ok('/index')
			->status_is(200)
			->header_is('Content-Type', 'text/html;charset=Shift_JIS')
			->content_is('日本語');
	}
    
    END {
        $ENV{MOJO_MODE} = $backup;
    }

package SomeApp;
use strict;
use warnings;
use base 'Mojolicious';
use MojoX::Util::BodyFilter 'enable';
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

package SomeApp2;
use strict;
use warnings;
use base 'Mojolicious';
use MojoX::Util::BodyFilter 'enable';
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

package SomeApp3;
use strict;
use warnings;
use base 'Mojolicious';
use MojoX::Util::BodyFilter 'enable';
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

package GrowLarge;
use strict;
use warnings;
use base 'Mojolicious';
use MojoX::Util::BodyFilter 'enable';
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

package HeadModified;
use strict;
use warnings;
use base 'Mojolicious';
use MojoX::Util::BodyFilter 'enable';
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

__END__

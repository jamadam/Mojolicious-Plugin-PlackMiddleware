use strict;
use warnings;
use Test::Memory::Cycle;
use Test::More;
use MojoX::Tusu;

    use Test::More tests => 1;
    
    my $app = SomeApp->new;
    memory_cycle_ok( $app );
    
        package SomeApp;
        use strict;
        use warnings;
        use base 'Mojolicious';
        use MojoX::Tusu;
        
        sub startup {
            my $self = shift;
            $self->plugin(plack_middleware => ['TestFilter2', sub {my $c = shift;1}, {charset => 'Shift_JIS'}]);
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
			};
			$res;
		});
	}

__END__

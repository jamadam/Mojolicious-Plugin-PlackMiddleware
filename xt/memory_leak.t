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
            $self->plugin(plack_middleware => ['ForceCharset', sub {my $c = shift;1}, {charset => 'Shift_JIS'}]);
        }

__END__
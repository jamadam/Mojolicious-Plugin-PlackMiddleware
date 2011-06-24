package Mojolicious::Plugin::PlackMiddleware;
use strict;
use warnings;
use Mojo::Server::PSGI;
use Mojo::Message::Response;
use Plack::Builder;
use Carp;
use Mojo::Base 'Mojolicious::Plugin';
our $VERSION = '0.08';

    sub register {
        my ($self, $app, $mws) = @_;
        $app->hook(after_dispatch => sub {
            my $c = shift;
            my @mws = @$mws;
            my $res = _generate_psgi_res($c->res);
            my $plack_app = sub {$res};
            while (my $e = shift @mws) {
                require File::Spec->catdir(split(/::/, $e)). '.pm';
                my $cond = (ref $mws[0] eq 'CODE') ? shift @mws : undef;
                my $args = (ref $mws[0] eq 'HASH') ? shift @mws : undef;
                if (! $cond || $cond->($c)) {
                    if ($args) {
                        $plack_app = $e->wrap($plack_app, %$args);
                    } else {
                        $plack_app = $e->wrap($plack_app);
                    }
                }
            }
            $c->tx->res(_generate_mojo_res($plack_app->()));
        });
    }
    
    sub _generate_mojo_res {
        my $psgi_res = shift;
        my $mojo_res = Mojo::Message::Response->new;
        $mojo_res->code($psgi_res->[0]);
        my $headers = $mojo_res->headers;
        while (scalar @{$psgi_res->[1]}) {
            $headers->header(shift @{$psgi_res->[1]} => shift @{$psgi_res->[1]});
        }
        
        # Content-Length should be set by mojolicious
        $headers->header('Content-Length' => 0);
        
        if (ref $psgi_res->[2] eq 'ARRAY') {
            $mojo_res->body(join '', @{$psgi_res->[2]});
        } else {
            $mojo_res->body($psgi_res->[2]->getline);
        }
        return $mojo_res;
    }
    
    sub _generate_psgi_res {
        
        my $mojo_res = shift;
        
        my $status = $mojo_res->code;
        my $headers = $mojo_res->content->headers;
        my @headers;
        for my $name (@{$headers->names}) {
            for my $values ($headers->header($name)) {
                push @headers, $name => $_ for @$values;
            }
        }
        
        my $body = Mojo::Server::PSGI::_Handle->new(_res => $mojo_res);
        return [$status, \@headers, $body];
    }

1;

__END__

=head1 NAME

MojoX::Util::PlackMiddleware - ResponseFilter in Plack::Middleware style

=head1 SYNOPSIS

    sub startup {
        ....
        
        my $self = shift;
        
        $self->plugin('plack_middleware', [
            'Plack::Middleware::Some1', 
            'Plack::Middleware::Some2', {arg1 => 'some_vale'}
        ]);
        $self->plugin('plack_middleware', [
            'Plack::Middleware::Some1', sub {$condition}, 
            'Plack::Middleware::Some2', sub {$condition}, {arg1 => 'some_vale'}
        ]);
    }
    
    package Plack::Middleware::Some;
    use strict;
    use warnings;
    use base qw( Plack::Middleware );
    
    sub call {
        
        my ($self, $env) = @_;
        $self->response_cb($self->app->($env), sub {
            my $res = shift;
            
            ### DO SOMETHING
            
            $res;
        });
    }

=head1 DESCRIPTION

Mojolicious::Plugin::PlackMiddleware allows you to enable Plack::Middleware
inside Mojolicious as after_dispatch hook.

=head1 METHODS

=head2 register

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

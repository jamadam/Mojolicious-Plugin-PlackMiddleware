package Mojolicious::Plugin::PlackMiddleware;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Server::PSGI;
use Plack::Util;
our $VERSION = '0.11';

    ### ---
    ### register
    ### ---
    sub register {
        my ($self, $app, $mws) = @_;
        
        my $on_process_org = $app->on_process;
        $app->on_process(sub {
            my ($app, $c) = @_;
            my $plack_app = sub {
                my $env = shift;
                my $tx_fixed = _psgi_env_to_mojo_tx($env);
                $on_process_org->($app, $c);
                return mojo_res_to_psgi_res($c->res);
            };
            my @mws = reverse @$mws;
            while (scalar @mws) {
                my $args = (ref $mws[0] eq 'HASH') ? shift @mws : undef;
                my $cond = (ref $mws[0] eq 'CODE') ? shift @mws : undef;
                my $e = shift @mws;
                $e = _load_class($e, 'Plack::Middleware');
                if (! $cond || $cond->($c)) {
                    if ($args) {
                        $plack_app = $e->wrap($plack_app, %$args);
                    } else {
                        $plack_app = $e->wrap($plack_app);
                    }
                }
            }
            my $plack_res = $plack_app->(_mojo_tx_to_psgi_env($c));
            if (! $c->stash('mojo.routed')) {
                $c->render_text(''); ## cheat mojolicious 
            }
            $c->tx->res(psgi_res_to_mojo_res($plack_res));
        });
    }
    
    ### ---
    ### convert mojo tx to psgi env
    ### ---
    sub _mojo_tx_to_psgi_env {
        my $c = shift;
        my $tx = $c->tx;
        my $url = $tx->req->url;
        my $env = {
            %ENV,
            'SERVER_PROTOCOL'   => 'HTTP/'. $tx->req->version,
            'SERVER_NAME'       => $url->base->host,
            'SERVER_PORT'       => $url->base->port,
            'HTTP_HOST'         => $url->base->host,
            'REQUEST_METHOD'    => $tx->req->method,
            'SCRIPT_NAME'       => '',
            'PATH_INFO'         => $url->path->to_string,
            'REQUEST_URI'       => $url->to_string,
            'QUERY_STRING'      => $url->query->to_string,
            'psgi.url_scheme'   => $url->base->scheme,
            'psgi.multithread'  => Plack::Util::FALSE,
            'psgi.version'      => [1,1],
            'psgi.input'        => *STDIN,
            'psgi.errors'       =>
                Mojolicious::Plugin::PlackMiddleware::_ErrorHandle->new($c->app), 
            'psgi.multithread'  => Plack::Util::FALSE,
            'psgi.multiprocess' => Plack::Util::TRUE,
            'psgi.run_once'     => Plack::Util::FALSE,
            'psgi.streaming'    => Plack::Util::TRUE,
            'psgi.nonblocking'  => Plack::Util::FALSE,
        };
        return $env;
    }
    
        ### ---
        ### convert mojo tx to psgi env
        ### ---
        {
            package Mojolicious::Plugin::PlackMiddleware::_ErrorHandle;
            use Mojo::Base -base;
            
            __PACKAGE__->attr('app');
            
            sub new {
                my ($class, $app) = @_;
                my $self = $class->SUPER::new;
                $self->app($app);
            }
            
            sub print {
                shift->app->log->debug(shift);
            }
        }
    
    use constant CHUNK_SIZE => $ENV{MOJO_CHUNK_SIZE} || 131072;
    
    ### ---
    ### convert psgi env to mojo tx
    ### ---
    sub _psgi_env_to_mojo_tx {
        my ($env) = @_;
        my $tx = Mojo::Transaction::HTTP->new;
        my $req = $tx->req;
        $req->parse($env);
        # Store connection information
        $tx->remote_address($env->{REMOTE_ADDR});
        $tx->local_port($env->{SERVER_PORT});
        
        # Request body
        my $len = $env->{CONTENT_LENGTH};
        while (!$req->is_done) {
            my $chunk = ($len && $len < CHUNK_SIZE) ? $len : CHUNK_SIZE;
            my $read = $env->{'psgi.input'}->read(my $buffer, $chunk, 0);
            last unless $read;
            $req->parse($buffer);
            $len -= $read;
            last if $len <= 0;
        }
        return $tx;
    }
    
    ### ---
    ### convert psgi res to mojo res
    ### ---
    sub psgi_res_to_mojo_res {
        my $psgi_res = shift;
        my $mojo_res = Mojo::Message::Response->new;
        $mojo_res->code($psgi_res->[0]);
        my $headers = $mojo_res->headers;
        while (scalar @{$psgi_res->[1]}) {
            $headers->header(shift @{$psgi_res->[1]} => shift @{$psgi_res->[1]});
        }
        
        # Content-Length should be set by mojolicious
        $headers->remove('Content-Length');
        
        my $asset = $mojo_res->content->asset;
        if (ref $psgi_res->[2] eq 'ARRAY') {
            for my $chunk (@{$psgi_res->[2]}) {
                $asset->add_chunk($chunk);
            }
        } else {
            while (my $chunk = $psgi_res->[2]->getline) {
                $asset->add_chunk($chunk);
            }
        }
        return $mojo_res;
    }
    
    ### ---
    ### convert mojo res to psgi res
    ### ---
    sub mojo_res_to_psgi_res {
        my $mojo_res = shift;
        my $status = $mojo_res->code;
        my $headers = $mojo_res->content->headers;
        my @headers;
        for my $name (@{$headers->names}) {
            for my $values ($headers->header($name)) {
                push @headers, $name => $_ for @$values;
            }
        }
        my @body;
        my $offset = 0;
        while (my $chunk = $mojo_res->get_body_chunk($offset)) {
            push(@body, $chunk);
            $offset += length $chunk;
        }
        return [$status, \@headers, \@body];
    }
    
    ### ---
    ### load mw class
    ### ---
    sub _load_class {
        my($class, $prefix) = @_;
        
        if ($prefix) {
            unless ($class =~ s/^\+// || $class =~ /^$prefix/) {
                $class = "$prefix\::$class";
            }
        }
        if ($class->can('call')) {
            return $class;
        }
        my $file = $class;
        $file =~ s!::!/!g;
        require "$file.pm"; ## no critic
    
        return $class;
    }

1;

__END__

=head1 NAME

MojoX::Util::PlackMiddleware - Plack::Middleware inside Mojolicious

=head1 SYNOPSIS

    sub startup {
        ....
        
        my $self = shift;
        
        # Mojolicious
        $self->plugin(plack_middleware => [
            'MyMiddleware1', 
            'MyMiddleware2', {arg1 => 'some_vale'},
            'MyMiddleware3', sub {$condition}, 
            'MyMiddleware4', sub {$condition}, {arg1 => 'some_vale'}
        ]);
        
        # Mojolicious::Lite
        plugin plack_middleware => [
            'MyMiddleware1', 
            'MyMiddleware2', {arg1 => 'some_vale'},
            'MyMiddleware3', sub {$condition}, 
            'MyMiddleware4', sub {$condition}, {arg1 => 'some_vale'}
        ];
    }
    
    package Plack::Middleware::MyMiddleware1;
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
inside Mojolicious by wrapping on_proccess.

=head2 OPTIONS

This plugin takes an argument in Array reference which contains some
middlewares. Each middleware can be followed by callback function for
conditional activation, and attributes for middleware.

    my $condition = sub {
        my $c = shift; # Mojolicious controller
        if (...) {
            return 1; # causes the middleware hooked
        }
    };
    plugin plack_middleware => [
        Plack::Middleware::MyMiddleware, $condition, {arg1 => 'some_vale'},
    ];

=head1 METHODS

=head2 register

$plugin->register;

Register plugin hooks in L<Mojolicious> application.

=head2 psgi_res_to_mojo_res

    my $mojo_res = psgi_res_to_mojo_res($psgi_res)

=head2 mojo_res_to_psgi_res

    my $psgi_res = mojo_res_to_psgi_res($mojo_res)

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

package MojoX::Util::BodyFilter;
use strict;
use warnings;
use Mojo::Server::PSGI;
use Plack::Builder;
our $VERSION = '0.01';

    sub set_mw {
        
        my $class = shift;
        my ($app, $mws) = @_;
        $app->hook(after_dispatch => sub {
            my $self = shift;
            my $res = _generate_psgi_res($self->res);
            my $plack_app = sub {$res};
            while (my $e = shift @$mws) {
                eval {
                    require File::Spec->catdir(split(/::/, $e)). '.pm';
                };
                if (! $@) {
                    if (ref $$mws[0] eq 'ARRAY') {
                        $plack_app = $e->wrap($plack_app, @{shift @$mws});
                    } else {
                        $plack_app = $e->wrap($plack_app);
                    }
                }
            }
            $res = $plack_app->();
            $self->res->body($res->[2]->getline);
        });
    }
    
    sub _generate_psgi_res {
        
        my $res = shift;
        
        my $status = $res->code;
        $res->fix_headers;
        my $headers = $res->content->headers;
        my @headers;
        for my $name (@{$headers->names}) {
            for my $values ($headers->header($name)) {
                push @headers, $name => $_ for @$values;
            }
        }
        
        my $body = Mojo::Server::PSGI::_Handle->new(_res => $res);
        return [$status, \@headers, $body];
    }

1;

__END__

=head1 NAME

MojoX::Util::BodyFilter - BodyFilter in Plack::Middleware style [EXPERIMENTAL]

=head1 SYNOPSIS

    sub startup {
        ....

        use MojoX::Util::BodyFilter;
        MojoX::Util::BodyFilter->set_mw($self, [
            'Plack::Middleware::Some',
            'Plack::Middleware::Some2' => \@args,
        ]);
    }
    
    package Some::MW1;
    use strict;
    use warnings;
    use base qw( Plack::Middleware );
    
    sub call {
        
        my $self = shift;
        my $res = $self->app->(@_);
        $self->response_cb($res, sub {
            my $res = shift;
            my $h = Plack::Util::headers($res->[1]);
            if ($h->get('Content-Type') =~ 'text/html') {
                return sub {
                    my $chunk = shift;
                    
                    ### DO SOMETHING
                    
                    return $chunk;
                };
            }
            $res;
        });
    }

=head1 DESCRIPTION

MojoX::Util::BodyFilter allows you to activate Plack::Middleware style body
filters on after_dispatch hook.

=head1 METHODS

=head2 MojoX::Util::BodyFilter->set_mw($mojo_app, $args_array_ref)

Sets Plack::Middleware::* to after_dispatch hook of mojo app as a callback.

    MojoX::Util::BodyFilter->set_mw($mojo_app, ['some::mw1','some::mw2'])

Middleware arguments can be set in array refs following to package name.

    MojoX::Util::BodyFilter->set_mw($mojo_app, [
        'some::mw1' => [$args1, $args2],
        'some::mw2' => [$args1, $args2],
    ])

=head1 SEE ALSO

L<Text::PSTemplate>, L<MojoX::Renderer>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

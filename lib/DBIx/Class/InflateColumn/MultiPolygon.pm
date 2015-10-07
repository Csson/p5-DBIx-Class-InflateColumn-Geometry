package DBIx::Class::InflateColumn::MultiPolygon;

use strict;
use warnings;
use DBIx::Class::InflateColumn::MultiPolygon::Info;

# VERSION
# ABSTRACT: Work easier with MultiPolygons

sub register_column {
    my($self, $column, $info, @rest) = @_;

    $self->next::method($column, $info, @rest);

    return if !defined $info->{'data_type'} || lc $info->{'data_type'} ne 'multipolygon';

    $self->inflate_column(
        $column => {
            inflate => sub {
                my($value, $object) = @_;
                my $result_source = $object;
                $result_source =~ s{^.*?Result::}{};
                $object->result_source->schema->storage->dbh_do(sub {
                    my($storage, $dbh, @args) = @_;

                    my %custom_radius = exists $info->{'sphere_radius'} ? (radius => $info->{'sphere_radius'}) : ();

                    DBIx::Class::InflateColumn::MultiPolygon::Info->new(%custom_radius, multi => decode_multipolygon($dbh->selectrow_arrayref("SELECT AsText(?)", {}, $value)->[0]));
                });
            },
            deflate => sub {
                my $value = shift;

                my $multipolygon = [];

                foreach my $group (@$value) {
                    my $textified = [ map { coord_string($_) } @$group ];

                    # The first element in this array ref is the outer ring,
                    # the following are the inner rings
                    push @$multipolygon => '(' . (join ",\n" => @$textified) . ')';
                }
                my $multipolygons_string = join ",\n" => @$multipolygon;

                return \qq{MultiPolygonFromText('MULTIPOLYGON($multipolygons_string)')};
            },
        }
    );
}


sub coord_string {
    my $polygon = shift;
    return '(' . (join ', ' => map { "$_->[0] $_->[1]" } @$polygon) . ')';
}

sub decode_multipolygon {
    my $multipolygon_astext = shift;
    $multipolygon_astext =~ s{^MultiPolygon\(}{}i;
    $multipolygon_astext = substr $multipolygon_astext, 0, -1;

    my $polygon_groups = [split m{\)\),\(\(}, $multipolygon_astext];

    my $multipolygon = [];

    foreach my $polygon_group (@$polygon_groups) {
        my $group = [];

        my $actual_polygons = [ split m{\),\(}, $polygon_group ];

        foreach my $actual_polygon (@$actual_polygons) {
            $actual_polygon =~ s{^\(+}{};
            $actual_polygon =~ s{\)+$}{};

            my $pairs = [map { my($long, $lat) = split / / => $_; { long => $long, lat => $lat } } split ',' => $actual_polygon];

            push @$group => $pairs;
        }
        push @$multipolygon => $group;
    }
    return $multipolygon;

}

1;
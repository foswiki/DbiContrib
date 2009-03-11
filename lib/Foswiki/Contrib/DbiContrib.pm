# Contrib for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright 2008, Sven Dowideit, SvenDowideit@fosiki.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Contrib::DbiContrib;
use strict;
use warnings;

use DBI;
use Error qw( :try );

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $pluginName $DB_instance);

$VERSION    = '$Rev: 0 (2008) $';
$pluginName = 'DbiContrib';
$RELEASE    = '';
$SHORTDESCRIPTION =
  'API for other Contribs and plugins to use to abstract Database accesses';

# class to use to get connection to db, and to run queries.
###############################################################################

=pod

---++ ClassMethod new( $session ) -> $object

=cut

sub new {
    my ( $class, $options ) = @_;

    #yep, we're a singleton
    return $DB_instance if ( defined($DB_instance) );

    my $this = bless( {}, $class );
    $DB_instance = $this;

    $this->{dsn}          = $Foswiki::cfg{DbiContrib}{DBI_dsn};
    $this->{dsn_user}     = $Foswiki::cfg{DbiContrib}{DBI_username};
    $this->{dsn_password} = $Foswiki::cfg{DbiContrib}{DBI_password};
    $this->{dsn_options}  = $options;

    #    unless ( $this->{dsn} =~ /mysql/i ) {
    #        die "only mysql supported";
    #    }

    return $this;
}

=pod

---++ ObjectMethod finish()
Break circular references.

Note to developers; please undef *all* fields in the object explicitly,
whether they are references or not. That way this method is "golden
documentation" of the live fields in the object.

=cut

sub finish {
    my $this = shift;
    if ( defined($DB_instance) ) {
        $this->disconnect();
        undef $DB_instance;
    }
    return;
}

=pod



=cut

sub connect {
    my $this = shift;

    unless ( defined( $this->{DB} ) ) {    #
        if (
            !(
                $this->{DB} = DBI->connect(
                    $this->{dsn}, $this->{dsn_user}, $this->{dsn_password}, $this->{dsn_options}
                )
            )
          )
        {
            print STDERR "Cannot connect: $DBI::errstr \n\n"
              . join( '___',
                ( $this->{dsn}, $this->{dsn_user}, $this->{dsn_password} ) );
            return;
        }
        $this->{DB}->{AutoCommit} = 0 if ($this->{dsn} =~ /:mysql:/);
        $this->{DB}->{RaiseError} = 1;
    }
    return $this->{DB};
}

sub commit {
    my $this = shift;
    if ( defined( $this->{DB} ) ) {
        $this->{DB}->commit();
    }
    return;
}

sub disconnect {
    my $this = shift;
    if ( defined( $this->{DB} ) ) {
        $this->commit();
        $this->{DB}->disconnect();
        undef $this->{DB};
    }
    return;
}

#returns an ref to an array dataset of rows
#dbSelect(query, @list of params to query)
sub dbSelect {
    my $this   = shift;
    my $query  = shift;
    my @params = @_;

    my $key = "$query : " . join( '-', @params );

    #print STDERR "getHashRef($key)\n";
    #is it cached in memory?
    return $this->{Results}{$key}
      if ( defined( $this->{Results}{$key} ) );

    my $dbh = $this->connect();
    try {

        #$dbh->{Profile} = 2;
        my $sth = $dbh->prepare($query);
        $sth->execute(@params);
        my $array_ref = $sth->fetchall_arrayref();

        #use Data::Dumper;
        #    print STDERR "cached: ".Dumper($hash_ref)."\n";

        #return $array_ref;

        $this->{Results}{$key} = $array_ref
          if ( defined( $array_ref->[0][0] ) );
    }
    catch Error::Simple with {
        $this->{error} = $!;
        print STDERR "            ERROR: fetch_select($key) : $! : ("
          . $dbh->errstr . ')';

        #$this->{session}->writeWarning("ERROR: fetch_select($key) : $!");
        my @array = ();
        $this->{Results}{$key} = \@array;
    };
    return $this->{Results}{$key};
}

#dbReplace(query, @list of params to query)
#replace or insert
sub dbInsert {
    my $this   = shift;
    my $query  = shift;
    my @params = @_;
    my $rows   = 0;

    my $dbh = $this->connect();
    try {

        #$dbh->{Profile} = 2;
        $rows = $dbh->do( $query, undef, @params );
    }
    catch Error::Simple with {
        $this->{error} = $!;
        my $key = "$query : " . join( '-', @params );
        print STDERR "            ERROR: do($key) : $! : ("
          . $dbh->errstr . ')';

        #$this->{session}->writeWarning("ERROR: do($key) : $!");
    };
    return $rows;
}

1;

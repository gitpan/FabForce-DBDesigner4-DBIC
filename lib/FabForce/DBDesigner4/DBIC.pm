package FabForce::DBDesigner4::DBIC;

use warnings;
use strict;
use Carp;
use File::Spec;
use FabForce::DBDesigner4;

=head1 NAME

FabForce::DBDesigner4::DBIC - create DBIC scheme for DBDesigner4 xml file

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    use FabForce::DBDesigner4::DBIC;

    my $foo = FabForce::DBDesigner4::DBIC->new();
    $foo->output_path( $some_path );
    $foo->namespace( 'MyApp::DB' );
    $foo->create_scheme( $xml_document );

=head1 METHODS

=head2 new

creates a new object of FabForce::DBDesigner4::DBIC. You can pass some parameters
to new (all parameters are optional)

  my $foo = FabForce::DBDesigner4::DBIC->new(
    output_path => '/path/to/dir',
    input_file  => '/path/to/dbdesigner.file',
    namespace   => 'MyApp::Database',
  );

=cut

sub new {
    my ($class,%args) = @_;
    
    my $self = {};
    bless $self, $class;
    
    $self->output_path( $args{output_path} );
    $self->input_file( $args{inputfile} );
    $self->namespace( $args{namespace} );
    
    return $self;
}

=head2 output_path

sets / gets the output path for the scheme

  $foo->output_path( '/any/directory' );
  print $foo->output_path;

=cut

sub output_path {
    my ($self,$path) = @_;
    
    $self->{output_path} = $path if defined $path;
    return $self->{output_path};
}

=head2 input_file

sets / gets the name of the DBDesigner file (XML format)

  $foo->input_file( 'dbdesigner.xml' );
  print $foo->input_file;

=cut

sub input_file{
    my ($self,$file) = @_;
    
    $self->{_input_file} = $file if defined $file;
    return $self->{_input_file};
}

=head2 create_scheme

creates all the files that are needed to work with DBIx::Class scheme:

The main module that loads all classes and one class per table. If you haven't
specified an input file, the module will croak.

You can specify the input file either with input_file or as an parameter for
create_scheme

  $foo->input_file( 'dbdesigner.xml' );
  $foo->create_scheme;
  
  # or
  
  $foo->create_scheme( 'dbdesigner.xml' );

=cut

sub create_scheme{
    my ($self, $inputfile) = @_;
    
    $inputfile ||= $self->input_file;
    
    croak "no input file defined" unless defined $inputfile;
    
    my $output_path = $self->output_path || '.';
    my $namespace   = $self->namespace;
    
    my $fabforce    = FabForce::DBDesigner4->new;
       $fabforce->parsefile( xml => $inputfile );
    my @tables      = $fabforce->getTables;
    
    my @files;
    my %relations;
    
    for my $table ( @tables ){
        my $name = $table->name;
        $self->_add_class( $name );
        my $rels = $table->get_foreign_keys;
        for my $to_table ( keys %$rels ){
            $relations{$to_table}->{to}->{$name}   = $rels->{$to_table};
            $relations{$name}->{from}->{$to_table} = $rels->{$to_table};
        }
    }
    
    my @scheme = $self->_main_template;
    
    for my $table ( @tables ){
        push @files, $self->_class_template( $table, $relations{$table->name} );
    }
    
    push @files, @scheme;
    
    $self->_write_files( @files );
}

=head2 namespace

sets / gets the name of the namespace. If you set the namespace to 'Test' and you
have a table named 'MyTable', the main module is named 'Test::DBIC_Scheme' and
the class for 'MyTable' is named 'Test::DBIC_Scheme::MyTable'

  $foo->namespace( 'MyApp::DB' );

=cut

sub namespace{
    my ($self,$namespace) = @_;
    
    $self->{namespace} = '' unless defined $self->{namespace};
    
    #print "yes: $namespace\n" if defined $namespace and $namespace =~ /^[A-Z]\w*(::\w+)*$/;
    
    if( defined $namespace and $namespace !~ /^[A-Z]\w*(::\w+)*$/  ){
        croak "no valid namespace given";
    }
    elsif( defined $namespace ){
        $self->{namespace} = $namespace;
    }

    return $self->{namespace};
}

sub _write_files{
    my ($self, %files) = @_;
    
    for my $package ( keys %files ){
        my @path;
        push @path, $self->output_path if $self->output_path;
        push @path, split /::/, $package;
        my $file = pop @path;
        my $dir  = File::Spec->catdir( @path );
        
        $dir = $self->_untaint_path( $dir );
        
        unless( -e $dir ){
            $self->_mkpath( $dir );
        }

        if( open my $fh, '>', $dir . '/' . $file . '.pm' ){
            print $fh $files{$package};
            close $fh;
        }
        else{
            croak "Couldn't create $file.pm";
        }
    }
}

sub _untaint_path{
    my ($self,$path) = @_;
    ($path) = ( $path =~ /(.*)/ );
    # win32 uses ';' for a path separator, assume others use ':'
    my $sep = ($^O =~ /win32/i) ? ';' : ':';
    # -T disallows relative directories in the PATH
    $path = join $sep, grep !/^\./, split /$sep/, $path;
    return $path;
}

sub _mkpath{
    my ($self, $path) = @_;
    
    my @parts = split /[\\\/]/, $path;
    
    for my $i ( 0..$#parts ){
        my $dir = File::Spec->catdir( @parts[ 0..$i ] );
        $dir = $self->_untaint_path( $dir );
        mkdir $dir unless -e $dir;
    }
}

sub _add_class{
    my ($self,$class) = @_;
    
    push @{ $self->{_classes} }, $class if defined $class;
}

sub _get_classes{
    my ($self) = @_;
    
    return @{ $self->{_classes} };
}

sub _scheme{
    my ($self,$name) = @_;
    
    $self->{_scheme} = $name if defined $name;
    return $self->{_scheme};
}

sub _has_many_template{
    my ($self, $to, $arrayref) = @_;
    
    my $package = $self->namespace . '::' . $self->_scheme . '::' . $to;
       $package =~ s/^:://;
    
    my $string = '';
    for my $arref ( @$arrayref ){
        my ($foreign_field,$field) = @$arref;
    
        $string .= qq~
__PACKAGE__->has_many($field => '$package',
             { 'foreign.$foreign_field' => 'self.$field' });
~;
    }

    return $string;
}

sub _belongs_to_template{
    my ($self, $from, $arrayref) = @_;
    
    my $package = $self->namespace . '::' . $self->_scheme . '::' . $from;
       $package =~ s/^:://;
    
    my $string = '';
    for my $arref ( @$arrayref ){
        my ($foreign_field,$field) = @$arref;
    
        $string .= qq~
__PACKAGE__->belongs_to($field => '$package',
             { 'foreign.$foreign_field' => 'self.$field' });
~;
    }

    return $string;
}

sub _class_template{
    my ($self,$table,$relations) = @_;
    
    my $name    = $table->name;
    my $package = $self->namespace . '::' . $self->_scheme . '::' . $name;
       $package =~ s/^:://;
    
    my ($has_many, $belongs_to) = ('','');
    
    for my $to_table ( keys %{ $relations->{to} } ){
        $has_many .= $self->_has_many_template( $to_table, $relations->{to}->{$to_table} );
    }

    for my $from_table ( keys %{ $relations->{from} } ){
        $belongs_to .= $self->_belongs_to_template( $from_table, $relations->{from}->{$from_table} );
    }
    
    my @columns = $table->column_names;
    my $column_string = join "\n", map{ "    " . $_ }@columns;
    
    my $primary_key   = join " ", $table->key;
    
    my $template = qq~package $package;
    
use strict;
use warnings;
use base qw(DBIx::Class);

__PACKAGE__->load_components( qw/PK::Auto Core/ );
__PACKAGE__->table( '$name' );
__PACKAGE__->add_columns( qw/
$column_string
/);
__PACKAGE__->set_primary_key( qw/ $primary_key / );

$has_many
$belongs_to

1;~;

    return $package, $template;
}

sub _main_template{
    my ($self) = @_;
    
    my @class_names  = $self->_get_classes;
    my $classes      = join "\n", map{ "    " . $_ }@class_names;
    
    my $scheme_name;
    my @scheme_names = qw(DBIC_Scheme Database DBIC MyScheme MyDatabase DBIxClass_Scheme);
    
    for my $scheme ( @scheme_names ){
        unless( grep{ $_ eq $scheme }@class_names ){
            $scheme_name = $scheme;
            last;
        }
    }

    croak "couldn't determine a package name for the scheme" unless $scheme_name;
    
    $self->_scheme( $scheme_name );
    
    my $namespace  = $self->namespace . '::' . $scheme_name;
       $namespace  =~ s/^:://;
       
    my $template = qq~package $namespace;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_classes(qw/
$classes
/);

1;~;

    return $namespace, $template;
}

=head1 AUTHOR

Renee Baecker, C<< <module at renee-baecker.de> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-fabforce-dbdesigner4-dbic at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=FabForce::DBDesigner4::DBIC>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc FabForce::DBDesigner4::DBIC

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/FabForce::DBDesigner4::DBIC>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/FabForce::DBDesigner4::DBIC>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=FabForce::DBDesigner4::DBIC>

=item * Search CPAN

L<http://search.cpan.org/dist/FabForce::DBDesigner4::DBIC>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Renee Baecker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of FabForce::DBDesigner4::DBIC

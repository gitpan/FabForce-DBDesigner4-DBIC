use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'FabForce::DBDesigner4::DBIC',
    license             => 'perl',
    dist_author         => 'Renee Baecker <module@renee-baecker.de>',
    dist_version_from   => 'lib/FabForce/DBDesigner4/DBIC.pm',
    build_requires => {
        'Test::More'            => 0,
        'FabForce::DBDesigner4' => 0.08,
        'File::Spec'            => 3.12,
        'Carp'                  => 0,
    },
    add_to_cleanup      => [ 'FabForce::DBDesigner4::DBIC-*' ],
);

$builder->create_build_script();

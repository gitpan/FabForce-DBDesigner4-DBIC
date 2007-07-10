#!perl -T

use Test::More tests => 1;
use Perl::Critic;
use FabForce::DBDesigner4::DBIC;

my $pc = Perl::Critic->new();
my @violations = $pc->critique($INC{'FabForce/DBDesigner4/DBIC.pm'});
is_deeply(\@violations,[],'Perl::Critic');

#!/gsc/bin/perl 
use strict; 
use Test::More qw/no_plan/;
use Test::Exception;
use FindBin qw($Bin);
use WashU::Billing::Controller;
use List::AllUtils qw(uniq);
use Try::Tiny;

my $int_file = $Bin. "/data/Bad_Dates.xlsx";

my $controller = WashU::Billing::Controller->new( spreadsheet => $int_file);
ok($controller, "got internal controller");

dies_ok { my @int = $controller->get_internal_invoice_units;} 'death due to multiple dates in spreadsheet.';

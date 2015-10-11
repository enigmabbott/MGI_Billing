package WashU::Billing::Model::InvoiceUnit;
 
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::StrictConstructor;
use List::AllUtils qw(sum uniq);

use warnings FATAL => qw(all);

extends 'DataAdapter::Result';
my @method = qw(
    primary_collaborator
    accounts_payable_contact
    project_name
    washu_deptnbr
    date
    ponbr
);

has 'row_data' => (
    is => 'rw',
    isa => 'ArrayRef[WashU::Billing::Model::AdapterBillingUnit]',
    trigger => sub {my $self = shift; $self->$_ for @method  }
);

has 'invoice_amount' => (
    is => 'rw',
    isa => 'Num',
    lazy_build => 1
);

enum DESTINATION => qw(internal external);

has 'invoice_destination' => (
    is => 'rw',
    isa => 'DESTINATION',
    required => 1
);

has 'invoice_sequence' => (
    is => 'rw',
    isa => 'Num',
);

use Class::MOP;

my $meta = Class::MOP::Class->initialize(__PACKAGE__);

for my $name (@method) {
    $meta->add_method(
        $name => sub {
            my $self = shift;
            my @names = uniq map{$_->$name} @{$self->row_data} or return '';
            if(scalar(@names) > 1){
                die "more than one $name not allowed: (". join(",", @names ) . ")" ;
            }
            return $names[0];
        }
    );
}

use Method::Alias washu_department => 'washu_deptnbr';


sub _build_invoice_amount {
   return sum map{$_->billabletotal}  @{shift->row_data};
}

no Moose;
1;


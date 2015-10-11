package WashU::Billing::Model::AdapterBillingUnit::Internal;

use Moose;
use Moose::Util::TypeConstraints;
use WashU::Billing::Model::CobolRecord;
use warnings FATAL => qw(all);
extends 'WashU::Billing::Model::AdapterBillingUnit';

sub totalqty_formatted {
    my $self = shift;

    my $definition= WashU::Billing::Model::CobolRecord->find_field_data_definition_by_description( 'item_quantity');

    my $item_quantity =sprintf("%d",$self->totalqty);
    $item_quantity = sprintf("%.2f", $self->totalqty )if ($item_quantity < 10);
   
    if(length($item_quantity) > $definition->{field_length}){
      $item_quantity ='';
    }

    return $item_quantity;
}

#spreadsheet attribute is sample_description but its called an
#item_description on the washU form

sub sample_description_formatted {
    my $definition= WashU::Billing::Model::CobolRecord->find_field_data_definition_by_description( 'item_description');

    return substr(shift->sample_description, 0, $definition->{field_length}),
}

sub activity_formatted {

    my $definition= WashU::Billing::Model::CobolRecord->find_field_data_definition_by_description( 'item_description');

    return substr( 'Activity: '.shift->activity, 0, $definition->{field_length});
}

sub invoice_group_by_string {
    my $self = shift;
    return $self->project_name . "::" . $self->washu_deptnbr;
}


no Moose;
1;


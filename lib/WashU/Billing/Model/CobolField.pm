package WashU::Billing::Model::CobolField;

use Moose; 
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
 
has position => ( 
    is => 'rw', 
    isa => 'Int',
    required => 1
);

has 'field_length' => (
    is => 'rw',
    isa => 'Int',
    required => 1
);

has description => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

subtype 'MooseTypeConstraintName' => as 'Str' =>
  where { find_type_constraint($_) } =>
  message { "Invalid field_type: $_ must be a moose type" };

has field_type => (
    is       => 'rw',
    isa      => 'MooseTypeConstraintName',
    required => 1
);

has value => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has record_code => (
    is => 'rw',
    isa => 'Int',
    required => 1
);

enum FIELD_REQUIREMENT => qw/Mandatory Optional Unused/;

has requirement_type => (
    is => 'rw',
    isa => 'FIELD_REQUIREMENT',
    required => 1
);

sub BUILD {
    my $self = shift;

    if($self->field_type =~ /Num|Int/ and $self->value){
        my $value = $self->value;
        $value =~ s/\$|,//g;

        if( $value < 0){
            die 'negative numbers not supported at: ' . $self->description . " value: " . $value;
        }
        $self->value($value);
    }

    if( $self->field_type eq 'Num' and $self->value){
        my $value = sprintf("%.2f", $self->value);
        $value =~ s/\.//;
        $self->value($value);
    }

    if(length($self->value) > $self->field_length){
        die  $self->description ." w/ value " .$self->value . " field value greater then allowed field length " .$self->field_length;
    }

    if($self->requirement_type eq 'Optional' and !$self->value  ){
        $self->field_type('Str');
        
    }

    if(length($self->value) < $self->field_length){
        my $pad = $self->field_length;
        if($self->field_type eq 'Str'){
            $self->value(  sprintf("%-$pad" ."s",$self->value));

        } else{
            $self->value(sprintf("%0$pad" ."s",$self->value));

        }
    }

    if($self->requirement_type eq 'Mandatory' and $self->value !~ /\S/  ){
        die "Mandatory field must have at least one value that is not a white space" 
    }

    find_type_constraint( $self->field_type )->assert_valid( $self->value);
    1;
} ;

__PACKAGE__->meta->make_immutable;
1;

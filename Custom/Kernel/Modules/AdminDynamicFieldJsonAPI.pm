# --
# Kernel/Modules/AdminDynamicFieldJsonAPI.pm - provides a dynamic fields text config view for admins
# Copyright (C) 2015 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDynamicFieldJsonAPI;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::System::Valid;
use Kernel::System::CheckItem;
use Kernel::System::DynamicField;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    for (qw(ParamObject LayoutObject LogObject ConfigObject)) {
        if ( !$Self->{$_} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
        }
    }

    # create additional objects
    $Self->{ValidObject} = Kernel::System::Valid->new( %{$Self} );

    $Self->{DynamicFieldObject} = Kernel::System::DynamicField->new( %{$Self} );

    # get configured object types
    $Self->{ObjectTypeConfig} = $Self->{ConfigObject}->Get('DynamicFields::ObjectType');

    # get the fields config
    $Self->{FieldTypeConfig} = $Self->{ConfigObject}->Get('DynamicFields::Driver') || {};

    # set possible values handling strings
    $Self->{EmptyString}     = '_DynamicFields_EmptyString_Dont_Use_It_String_Please';
    $Self->{DuplicateString} = '_DynamicFields_DuplicatedString_Dont_Use_It_String_Please';
    $Self->{DeletedString}   = '_DynamicFields_DeletedString_Dont_Use_It_String_Please';

    $Self->{ConfigParams} = [qw(
        ObjectType ObjectTypeName FieldType FieldTypeName ValidID Link
        JSONPathKey JSONPathValue HTTPMethod PasswordToken User URL TTLCache Requestbody
        PossibleNone
    )];

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( $Self->{Subaction} eq 'Add' ) {
        return $Self->_Add(
            %Param,
        );
    }
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        return $Self->_AddAction(
            %Param,
        );
    }
    if ( $Self->{Subaction} eq 'Change' ) {
        return $Self->_Change(
            %Param,
        );
    }
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        return $Self->_ChangeAction(
            %Param,
        );
    }
    return $Self->{LayoutObject}->ErrorScreen(
        Message => "Undefined subaction.",
    );
}

sub _Add {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    for my $Needed (qw(ObjectType FieldType FieldOrder)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$Needed ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Need $Needed",
            );
        }
    }

    # get the object type and field type display name
    my $ObjectTypeName = $Self->{ObjectTypeConfig}->{ $GetParam{ObjectType} }->{DisplayName} || '';
    my $FieldTypeName  = $Self->{FieldTypeConfig}->{ $GetParam{FieldType} }->{DisplayName}   || '';

    return $Self->_ShowScreen(
        %Param,
        %GetParam,
        Mode           => 'Add',
        ObjectTypeName => $ObjectTypeName,
        FieldTypeName  => $FieldTypeName,
    );
}

sub _AddAction {
    my ( $Self, %Param ) = @_;

    my %Errors;
    my %GetParam;

    for my $Needed (qw(Name Label FieldOrder URL JSONPathKey HTTPMethod)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            $Errors{ $Needed . 'ServerError' }        = 'ServerError';
            $Errors{ $Needed . 'ServerErrorMessage' } = 'This field is required.';
        }
    }

    if ( $GetParam{Name} ) {

        # check if name is alphanumeric
        if ( $GetParam{Name} !~ m{\A (?: [a-zA-Z] | \d )+ \z}xms ) {

            # add server error error class
            $Errors{NameServerError} = 'ServerError';
            $Errors{NameServerErrorMessage} =
                'The field does not contain only ASCII letters and numbers.';
        }

        # check if name is duplicated
        my %DynamicFieldsList = %{
            $Self->{DynamicFieldObject}->DynamicFieldList(
                Valid      => 0,
                ResultType => 'HASH',
                )
        };

        %DynamicFieldsList = reverse %DynamicFieldsList;

        if ( $DynamicFieldsList{ $GetParam{Name} } ) {

            # add server error error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = 'There is another field with the same name.';
        }
    }

    if ( $GetParam{FieldOrder} ) {

        # check if field order is numeric and positive
        if ( $GetParam{FieldOrder} !~ m{\A (?: \d )+ \z}xms ) {

            # add server error error class
            $Errors{FieldOrderServerError}        = 'ServerError';
            $Errors{FieldOrderServerErrorMessage} = 'The field must be numeric.';
        }
    }

    for my $ConfigParam ( @{ $Self->{ConfigParams} || [] } ) {
        $GetParam{$ConfigParam} = $Self->{ParamObject}->GetParam( Param => $ConfigParam );
    }

    # uncorrectable errors
    if ( !$GetParam{ValidID} ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ValidID",
        );
    }

    # return to add screen if errors
    if (%Errors) {
        return $Self->_ShowScreen(
            %Param,
            %Errors,
            %GetParam,
            Mode           => 'Add',
        );
    }

    # set specific config
    my @Keys = @{ $Self->{ConfigParams} || [] };
    my %FieldConfig;
    @FieldConfig{@Keys} = @GetParam{@Keys};

    # create a new field
    my $FieldID = $Self->{DynamicFieldObject}->DynamicFieldAdd(
        Name       => $GetParam{Name},
        Label      => $GetParam{Label},
        FieldOrder => $GetParam{FieldOrder},
        FieldType  => $GetParam{FieldType},
        ObjectType => $GetParam{ObjectType},
        Config     => \%FieldConfig,
        ValidID    => $GetParam{ValidID},
        UserID     => $Self->{UserID},
    );

    if ( !$FieldID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not create the new field",
        );
    }

    return $Self->{LayoutObject}->Redirect(
        OP => "Action=AdminDynamicField",
    );
}

sub _Change {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    for my $Needed (qw(ObjectType FieldType)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$Needed ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Need $Needed",
            );
        }
    }

    # get the object type and field type display name
    my $ObjectTypeName = $Self->{ObjectTypeConfig}->{ $GetParam{ObjectType} }->{DisplayName} || '';
    my $FieldTypeName  = $Self->{FieldTypeConfig}->{ $GetParam{FieldType} }->{DisplayName}   || '';

    my $FieldID = $Self->{ParamObject}->GetParam( Param => 'ID' );

    if ( !$FieldID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ID",
        );
    }

    # get dynamic field data
    my $DynamicFieldData = $Self->{DynamicFieldObject}->DynamicFieldGet(
        ID => $FieldID,
    );

    # check for valid dynamic field configuration
    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not get data for dynamic field $FieldID",
        );
    }

    my %Config;

    # extract configuration
    if ( IsHashRefWithData( $DynamicFieldData->{Config} ) ) {
        my @Keys = @{ $Self->{ConfigParams} || [] };
        @Config{@Keys} = @{ $DynamicFieldData->{Config} }{@Keys};
    }

    return $Self->_ShowScreen(
        %Param,
        %GetParam,
        %${DynamicFieldData},
        %Config,
        ID             => $FieldID,
        Mode           => 'Change',
        ObjectTypeName => $ObjectTypeName,
        FieldTypeName  => $FieldTypeName,
    );
}

sub _ChangeAction {
    my ( $Self, %Param ) = @_;

    my %Errors;
    my %GetParam;

    for my $Needed (qw(Name Label FieldOrder JSONPathKey URL HTTPMethod)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            $Errors{ $Needed . 'ServerError' }        = 'ServerError';
            $Errors{ $Needed . 'ServerErrorMessage' } = 'This field is required.';
        }
    }

    my $FieldID = $Self->{ParamObject}->GetParam( Param => 'ID' );
    if ( !$FieldID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ID",
        );
    }

    # get dynamic field data
    my $DynamicFieldData = $Self->{DynamicFieldObject}->DynamicFieldGet(
        ID => $FieldID,
    );

    # check for valid dynamic field configuration
    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not get data for dynamic field $FieldID",
        );
    }

    if ( $GetParam{Name} ) {

        # check if name is lowercase
        if ( $GetParam{Name} !~ m{\A (?: [a-zA-Z] | \d )+ \z}xms ) {

            # add server error error class
            $Errors{NameServerError} = 'ServerError';
            $Errors{NameServerErrorMessage} =
                'The field does not contain only ASCII letters and numbers.';
        }

        # check if name is duplicated
        my %DynamicFieldsList = %{
            $Self->{DynamicFieldObject}->DynamicFieldList(
                Valid      => 0,
                ResultType => 'HASH',
                )
        };

        %DynamicFieldsList = reverse %DynamicFieldsList;

        if (
            $DynamicFieldsList{ $GetParam{Name} } &&
            $DynamicFieldsList{ $GetParam{Name} } ne $FieldID
            )
        {

            # add server error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = 'There is another field with the same name.';
        }

        # if it's an internal field, it's name should not change
        if (
            $DynamicFieldData->{InternalField} &&
            $DynamicFieldsList{ $GetParam{Name} } ne $FieldID
            )
        {

            # add server error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = 'The name for this field should not change.';
            $Param{InternalField}           = $DynamicFieldData->{InternalField};
        }
    }

    if ( $GetParam{FieldOrder} ) {

        # check if field order is numeric and positive
        if ( $GetParam{FieldOrder} !~ m{\A (?: \d )+ \z}xms ) {

            # add server error error class
            $Errors{FieldOrderServerError}        = 'ServerError';
            $Errors{FieldOrderServerErrorMessage} = 'The field must be numeric.';
        }
    }

    for my $ConfigParam ( @{ $Self->{ConfigParams} || [] } ) {
        $GetParam{$ConfigParam} = $Self->{ParamObject}->GetParam( Param => $ConfigParam );
    }

    # uncorrectable errors
    if ( !$GetParam{ValidID} ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ValidID",
        );
    }

    # return to change screen if errors
    if (%Errors) {
        return $Self->_ShowScreen(
            %Param,
            %Errors,
            %GetParam,
            ID             => $FieldID,
            Mode           => 'Change',
        );
    }

    # set specific config
    my @Keys = @{ $Self->{ConfigParams} || [] };
    my %FieldConfig;
    @FieldConfig{@Keys} = @GetParam{@Keys};

    # update dynamic field (FieldType and ObjectType cannot be changed; use old values)
    my $UpdateSuccess = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
        ID         => $FieldID,
        Name       => $GetParam{Name},
        Label      => $GetParam{Label},
        FieldOrder => $GetParam{FieldOrder},
        FieldType  => $DynamicFieldData->{FieldType},
        ObjectType => $DynamicFieldData->{ObjectType},
        Config     => \%FieldConfig,
        ValidID    => $GetParam{ValidID},
        UserID     => $Self->{UserID},
    );

    if ( !$UpdateSuccess ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not update the field $GetParam{Name}",
        );
    }

    return $Self->{LayoutObject}->Redirect(
        OP => "Action=AdminDynamicField",
    );
}

sub _ShowScreen {
    my ( $Self, %Param ) = @_;

    $Param{DisplayFieldName} = 'New';

    if ( $Param{Mode} eq 'Change' ) {
        $Param{ShowWarning}      = 'ShowWarning';
        $Param{DisplayFieldName} = $Param{Name};
    }

    $Param{DeletedString} = $Self->{DeletedString};

    # header
    my $Output = $Self->{LayoutObject}->Header();
    $Output .= $Self->{LayoutObject}->NavigationBar();

    # get all fields
    my $DynamicFieldList = $Self->{DynamicFieldObject}->DynamicFieldListGet(
        Valid => 0,
    );

    # get the list of order numbers (is already sorted).
    my @DynamicfieldOrderList;
    my %DynamicfieldNamesList;
    for my $Dynamicfield ( @{$DynamicFieldList} ) {
        push @DynamicfieldOrderList, $Dynamicfield->{FieldOrder};
        $DynamicfieldNamesList{ $Dynamicfield->{FieldOrder} } = $Dynamicfield->{Label};
    }

    # when adding we need to create an extra order number for the new field
    if ( $Param{Mode} eq 'Add' ) {

        # get the last element form the order list and add 1
        my $LastOrderNumber = $DynamicfieldOrderList[-1];
        $LastOrderNumber++;

        # add this new order number to the end of the list
        push @DynamicfieldOrderList, $LastOrderNumber;
    }

    # show the names of the other fields to ease ordering
    my %OrderNamesList;
    my $CurrentlyText = $Self->{LayoutObject}->{LanguageObject}->Translate('Currently') . ': ';
    for my $OrderNumber ( sort @DynamicfieldOrderList ) {
        $OrderNamesList{$OrderNumber} = $OrderNumber;
        if ( $DynamicfieldNamesList{$OrderNumber} && $OrderNumber ne $Param{FieldOrder} ) {
            $OrderNamesList{$OrderNumber}
                = $OrderNumber . ' - '
                . $CurrentlyText
                . $DynamicfieldNamesList{$OrderNumber}
        }
    }

    my $DynamicFieldOrderStrg = $Self->{LayoutObject}->BuildSelection(
        Data          => \%OrderNamesList,
        Name          => 'FieldOrder',
        SelectedValue => $Param{FieldOrder} || 1,
        PossibleNone  => 0,
        Translation   => 0,
        Sort          => 'NumericKey',
        Class         => 'W75pc Validate_Number',
    );

    my %ValidList = $Self->{ValidObject}->ValidList();

    # create the Validity select
    my $ValidityStrg = $Self->{LayoutObject}->BuildSelection(
        Data         => \%ValidList,
        Name         => 'ValidID',
        SelectedID   => $Param{ValidID} || 1,
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'W50pc',
    );

    # define as 0 to get the real value in the HTML
    my $ValueCounter = 0;

    # create treeview option list
    $Param{HTTPMethodSelect} = $Self->{LayoutObject}->BuildSelection(
        Data => {
            GET  => 'GET',
            POST => 'POST',
        },
        Name       => 'HTTPMethod',
        SelectedID => $Param{HTTPMethod} || 'GET',
        Class      => 'W50pc',
    );

    # create treeview option list
    $Param{PossibleNoneSelect} = $Self->{LayoutObject}->BuildSelection(
        Data => {
            1 => 'Yes',
            0 => 'No',
        },
        Name       => 'PossibleNone',
        SelectedID => $Param{PossibleNone} || '0',
        Translation => 1,
        Class      => 'W50pc',
    );

    my $Link = $Param{Link} || '';

    my $ReadonlyInternalField = '';

    # Internal fields can not be deleted and name should not change.
    if ( $Param{InternalField} ) {
        $Self->{LayoutObject}->Block(
            Name => 'InternalField',
            Data => {%Param},
        );
        $ReadonlyInternalField = 'readonly="readonly"';
    }

    # generate output
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminDynamicFieldJsonAPI',
        Data         => {
            %Param,
            ValidityStrg           => $ValidityStrg,
            DynamicFieldOrderStrg  => $DynamicFieldOrderStrg,
            ReadonlyInternalField  => $ReadonlyInternalField,
        }
    );

    $Output .= $Self->{LayoutObject}->Footer();

    return $Output;
}

1;

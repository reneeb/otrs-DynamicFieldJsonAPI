# --
# Kernel/Modules/PublicDeleteDFCache.pm - delete cache for DynamicFieldValues
# Copyright (C) 2015 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::PublicDeleteDFCache;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Output::HTML::Layout
    Kernel::System::Web::Request
    Kernel::System::Cache
);

our $VERSION = 0.01;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CacheObject  = $Kernel::OM->Get('Kernel::System::Cache');

    my $Field = $ParamObject->GetParam( Param => 'Name' ) || '';
    $Field =~ s{[^A-Za-z0-9]}{}g;

    $CacheObject->Delete(
        Type => 'DynamicFieldValues',
        Key  => 'DynamicField::' . $Field,
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => '{"success":1}',
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;

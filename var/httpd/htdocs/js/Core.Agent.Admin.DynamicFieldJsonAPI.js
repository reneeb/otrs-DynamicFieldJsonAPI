// --
// Core.Agent.Admin.DynamicFieldJsonAPI.js - provides the special module functions for the Multiselect Dynamic Fields.
// Copyright (C) 2015 Perl-Services.de, http://perl-services.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.Admin.DynamicFieldMultiselect
 * @description
 *      This namespace contains the special module functions for the DynamicFieldMultiselect module.
 */
Core.Agent.Admin.DynamicFieldJsonAPI = (function (TargetNS) {

    /**
     * @function
     * @param {string} IDSelector, id of the pressed remove value button.
     * @return nothing
     *      This function removes a value from possible values list and creates a stub input so
     *      the server can identify if a value is empty or deleted (useful for server validation)
     *      It also deletes the Param from the DefaultParams list
     */
    TargetNS.RemoveParam = function (IDSelector){

        // copy HTML code for an input replacement for the deleted value
        var $Clone = $('.DeletedParam').clone(),

        // get the index of the value to delete (its always the second element (1) in this RegEx
        $ObjectIndex = IDSelector.match(/.+_(\d+)/)[1],

        // get the key name to remove it from the defaults select
        $Key = $('#Key_' + $ObjectIndex).val();

        // set the input replacement attributes to match the deleted original value
        // new value and other controls are not needed anymore
        $Clone.attr('id', 'Key' + '_' + $ObjectIndex);
        $Clone.attr('name', 'Key' + '_' + $ObjectIndex);
        $Clone.removeClass('DeletedParam');

        // add the input replacement to the mapping type so it can be parsed and distinguish from
        // empty values by the server
        $('#'+ IDSelector).closest('fieldset').append($Clone);

        // remove the value from default list
        if ($Key !== ''){
            $('#DefaultParam').find("option[value='"+ $Key +"']").remove();
        }

        // remove possible value
        $('#'+ IDSelector).parent().remove();

        return false;
    };

    /**
     * @function
     * @param {Object} ParamInsert, HTML container of the value mapping row
     * @return nothing
     *      This function add a new value to the possible values list
     */
    TargetNS.AddParam = function (ParamInsert) {

        // clone key dialog
        var $Clone = $('.ParamTemplate').clone(),
            ParamCounter = $('#ParamCounter').val();

        // increment key counter
        ParamCounter ++;

        // remove unnecessary classes
        $Clone.removeClass('Hidden ParamTemplate');

        // add needed class
        $Clone.addClass('ParamRow');

        // copy values and change ids and names
        $Clone.find(':input, a.RemoveButton').each(function(){
            var ID = $(this).attr('id');
            $(this).attr('id', ID + '_' + ParamCounter);
            $(this).attr('name', ID + '_' + ParamCounter);

            $(this).addClass('Validate_Required');

            // set error controls
            $(this).parent().find('#' + ID + 'Error').attr('id', ID + '_' + ParamCounter + 'Error');
            $(this).parent().find('#' + ID + 'Error').attr('name', ID + '_' + ParamCounter + 'Error');

            $(this).parent().find('#' + ID + 'ServerError').attr('id', ID + '_' + ParamCounter + 'ServerError');
            $(this).parent().find('#' + ID + 'ServerError').attr('name', ID + '_' + ParamCounter + 'ServerError');

            // add event handler to remove button
            if( $(this).hasClass('RemoveButton') ) {

                // bind click function to remove button
                $(this).bind('click', function () {
                    TargetNS.RemoveParam($(this).attr('id'));
                    return false;
                });
            }
        });

        $Clone.find('label').each(function(){
            var FOR = $(this).attr('for');
            $(this).attr('for', FOR + '_' + ParamCounter);
        });

        // append to container
        ParamInsert.append($Clone);

        // set new value for KeyName
        $('#ParamCounter').val(ParamCounter);

        return false;
    };

    return TargetNS;
}(Core.Agent.Admin.DynamicFieldJsonAPI || {}));

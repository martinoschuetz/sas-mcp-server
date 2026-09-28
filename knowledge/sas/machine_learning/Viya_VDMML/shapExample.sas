/* Parallelization Parameters */
numParallelSessions = 25;

/* Model/Table Information */
table = {name="iris",caslib="CASUSERHDFS"};
shapOut = {name="iris_shap",caslib="CASUSER"};
predictedTarget = "P_SepalLength";
modelTableType = "ASTORE";
code = "";
depth = 1;
modelTable = {name="FOREST_IRIS"};
modelTables = {};
astoreID = {};
inputs = {"SepalWidth", "PetalLength", "PetalWidth", "Species"};
nominals = {"PetalWidth", "Species"};

spacePattern = prxparse('s/\n[ ]*//');

/* Drop Output Table if it exists */
_quiet = callAction(
    "table.dropTable",
    {
        name="iris_shap",
        caslib="CASUSER"
        quiet=True
    }
);

/* Train Model */
_quiet = callAction(
    "table.dropTable",
    {
        name="FOREST_IRIS",
        quiet=True
    }
);
_quiet = callAction(
    "decisionTree.forestTrain",
    {
        table={
            name="iris"
        },
        seed=1234,
        saveState={
            name='FOREST_IRIS',
            promote=True
        },
        target="SepalLength",
        nTree=5,
        inputs={"SepalWidth", "PetalLength", "PetalWidth", "Species"},
        nominals={"PetalWidth", "Species"}
    }
);

/* Clean shapley Action Inputs */
initializeGlobal("code","");
setCaslib(table, activeCaslib());
setCaslib(shapOut, activeCaslib());
if dim(modelTable) > 0 then setCaslib(modelTable, activeCaslib());
do i = 1 to dim(modelTables);
    setCaslib(modelTables[i], activeCaslib());
end;

/* Create ID Column */
source ds_code;

    data {{score_name}}(caslib="{{score_caslib}}");
        set {{train_name}}(caslib="{{train_caslib}}");
        __NSHAP_ID__ = _N_;
    run;

endsource;
formatString(
    ds_code,
    {
        train_name = table["name"],
        train_caslib = table["caslib"],
        score_name = shapOut["name"],
        score_caslib = shapOut["caslib"]
    }
);
_quiet = callAction("datastep.runCode", {code = ds_code, single = "YES"});

/* Get Score Column (Using LinearExplainer) */
lex_parms = {
    table = shapOut,
    astoreID = astoreID,
    inputs = inputs + {"__NSHAP_ID__"}, /* ID Here For Copying */
    nominals = nominals,
    predictedTarget = predictedTarget,
    modelTableType = modelTableType,
    preset = "GLOBALREG",
    generatedOut = {name = '__MODEL_PREDS__',replace = True}
};
if code != "" then lex_parms["code"] = code;
if dim(modelTable) > 0 then lex_parms["modelTable"] = modelTable;
if dim(modelTables) > 0 then lex_parms["modelTables"] = modelTables;
lex_parms["query"] = shapOut;
lex_parms["query"]["where"] = "__NSHAP_ID__ = 1";

_quiet = callAction("explainModel.linearExplainer",lex_parms);

/* Merge In Predictions */
source ds_code;

    data {{name}}(caslib="{{caslib}}" promote=YES);
        merge {{name}}(caslib="{{caslib}}") __MODEL_PREDS__(keep = __NSHAP_ID__ {{predictedTarget}} _queryID_);
        by __NSHAP_ID__;
        if _queryID_ = 0;
        drop _queryID_;
    run;

endsource;
formatString(ds_code,shapOut + {predictedTarget = predictedTarget});
_quiet = callAction("datastep.runCode", {code = ds_code, single = "YES"});

/* Common Shapley Explainer Parameters */
shap_parms = {
    table = shapOut,
    astoreID = astoreID,
    inputs = inputs,
    nominals = nominals,
    predictedTarget = predictedTarget,
    modelTableType = modelTableType,
    depth = depth
};
if code != "" then shap_parms["code"] = code;
if dim(modelTable) > 0 then shap_parms["modelTable"] = modelTable;
if dim(modelTables) > 0 then shap_parms["modelTables"] = modelTables;

/* Shapley Call For Each Obersvation */
shapley_calls = {};
do i = 1 to numRows(shapOut);
    shap_parm_copy = shap_parms;
    shap_parm_copy["query"] = shapOut;
    shap_parm_copy["query"]["where"] = "__NSHAP_ID__ = " ||  (String) i;
    shapley_calls = shapley_calls + {{"explainModel.shapleyExplainer",shap_parm_copy}};
end;

/* Run all Shapley Calls */
shapley_results = runParallelActions(shapley_calls,numParallelSessions,1);

/* Create Shapley Value Table */
shap_columns = {"__NSHAP_ID__"};
shap_types = {"double"};
do var over shapley_results[1]["result"]["ShapleyValues"][,"Variable"];
    shap_columns = shap_columns + {"S_" || var};
    shap_types = shap_types + {"double"};
end;

shap_table = newTable(
    "shap_table",
    shap_columns,
    shap_types
);

do index, result over shapley_results;
    addrow(shap_table, {index} + result["result"]["ShapleyValues"][,"ShapleyValue"]);
end;

saveresult shap_table casout = "__SHAP_VALUES__" replace;

/* merge shap values with original data */
source ds_code;

    data {{name}}(caslib="{{caslib}}");
        merge {{name}}(caslib="{{caslib}}") __SHAP_VALUES__;
        by __NSHAP_ID__;
    run;

endsource;
formatString(ds_code,shapOut);
_quiet = callAction("datastep.runCode", {code = ds_code, single = "YES"});

/* Print Result */
print fullFetch(shapOut);
























/* Library Functions */

function activeCaslib();
    /*
        getActiveCaslib() returns the active caslib
    */

    caslibinfo result = lib / active = True;
    return lib["CASLibInfo"][1,"Name"];

end;

function setKey(in_out dict, key, default);
    /*
        setKey() sets the key in the dict to the default if its not already set

        Arguments:
        1. dict (Dictionary) - dict to modify
        2. key (String) - dictionary key to modify
        3. default (Any) - default value
    */

    if !exists(dict,key) then dict[key] = default;
end;

function setCaslib(in_out table, caslib);
    /*
        setCaslib() sets the value for a table's caslib if it's not already set

        Arguments:
        1. table (Dictionary) - CASTable specification
        2. caslib (String) - caslib to add to table specification
    */

    setKey(table,"caslib",caslib);
end;

function setName(in_out table, name);
    /*
        setDefaultTableName() sets the value for a table's name if it's not already set

        Arguments:
        1. table (Dictionary) - CASTable specification
        2. name (String) - name to add to table specification
    */

    setKey(table,"name",name);
end;

/* Pop Element From Array */
function pop(arr);
    /*
        pop() returns the first element from an array and removes that element from the array

        Arguments:
        1. arr (List) - list-like from which to pop value
    */

    ret = arr[1];
    if dim(arr) > 1 then arr = arr[2:dim(arr)];
    else arr = {};
    return ret;

end;

function fullFetch(table);
    /*
        fullFetch() returns all the rows of a Fetched table

        Arguments:
        1. table (String or Dictionary) - CASTable Specification
    */

    /* Fetch Table */
    num_obs = numRows(table);
    fetch = callAction("table.fetch",{table=table, to=num_obs, maxRows=num_obs, sasTypes=False});
    return fetch["result"]["Fetch"];

end;

function formatString(in_out string_to_format,format_parameters);
    /*
        formatString() mimics python's .format string method. Replaces {{key}} with value for each key,value pair in
        format parameters dictionary.

        Arguments:
        1. string_to_format (string) - string to be formatted
        2. format_parameters (dictionary) - dictionary of format parameters
    */

    do key, val over format_parameters;
        string_to_format = tranwrd(string_to_format, "{{" || key || "}}", (String) val);
    end;

end;

function checkStatus(status);
    /*
        checkStatus() checks the status of a CAS action. Returns True for bad status.
    */

    if status["severity"] >= 2 then return True;
    else return False;

end;

function callAction(action, parameters, async_session);
    /*
        callAction() calls an action with the given parameters. Exits if the action fails, returns result object otherwise.
    */

    if isString(async_session) then do;

        execute(action || " session = '" || async_session || "' async = 'ASYNC' / parameters;");

    end; else do;

        execute(action || " result = CA_RES status = CA_ST / parameters;");
        if checkStatus(CA_ST) then panic(CA_ST);
        return(
            {
                result = CA_RES,
                status = CA_ST
            }
        );

    end;

end;

function panic(printable);
    /*
        panic() stops executing CASL code, drops transient tables, prints the argument, and exits immediately.
    */

    print printable;
    print "Action stopped due to errors.";
    exit(
        {
            severity = 2,
            reason = 5
        }
    );

end;

function numRows(table);
    /*
        numRows() returns the number rows of a CAS table

        Arguments:
        1. table (String or Dictionary) - CASTable Specification
    */

    /* Determine Number of Rows in Table */
    numrows = callAction("simple.numrows",{table = table});
    return numrows["result"]["NumRows"];

end;

function runParallelActions(action_array, num_sessions, nworkers);
    /*
        runParallelActions() executes an array of action calls in parallel and returns their results.
        Results are returned in the same order as the action_array argument.

        Arguments:
        1. action_array (Array) - array of action specifications to run. An action specification is
                                  a two-element array where the first element is the action name and
                                  the second element is the action parameters.
        2. num_sessions (Int) - number of sessions to execute actions in asynchronously
        3. nworkers (Int) - number of workers to use in each session. 0 means 'All available workers'
    */

    /* Action Call Bookeeping */
    action_results = {};
    submitted_actions = {};

    /* Start Parallel Sessions */
    sessions = {};
    do i = 1 to num_sessions;
        if nworkers < 1 then sessions[i] = create_parallel_session();
        else sessions[i] = create_parallel_session(nworkers);
    end;
    available_sessions = sessions;

    /* Big Loop */
    still_working = True;
    next_action = 1;
    do while(still_working);

        top_loop:

        still_working = False;

        /* Submit Remaining Actions */
        if next_action <= dim(action_array) and dim(available_sessions) > 0 then do;

            still_working = True;

            /* Grab Session and Action Information */
            session = pop(available_sessions);
            action = action_array[next_action];
            submitted_actions[session] = next_action;
            next_action = next_action + 1;

            /* Submit Action, Restart Loop */
            callAction(action[1], action[2], session);
            goto top_loop;

        end;

        /* Gather Submitted Actions */
        job = wait_for_next_action(0);
        if job then do;

            still_working = True;

            /* Store Action Results */
            session = job['session'];
            action_number = submitted_actions[session];
            action_results[action_number] = job;

            /* Re-Use Session */
            delete submitted_actions[session];
            available_sessions = available_sessions + {session};

        end;

        /* Catch Unreturned Actions */
        if dim(submitted_actions) > 0 then still_working = True;

    end;

    /* End Parallel Sessions */
    do session over sessions;
        term_parallel_session(session);
    end;

    return action_results;

end;

function initializeGlobal(symbol, value);
    /*
        defineGlobal defines the symbol globally if it doesn't already exist and initializes it's value

        Arguments:
        1. symbol (String) - Variable whose existance to check for
        2. value (Any) - value to initialize variable to
    */

    if !exists(symbol) then do;
        execute("global " || symbol || ";");
        execute(symbol || " = value;");
    end;

end;
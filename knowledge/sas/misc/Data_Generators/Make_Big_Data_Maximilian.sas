libname data "c:\public";

/* Macro in order to simulate a dataset with a large number of observations
(more than 5000000) containing several independent variables drawn from two
multivariate normal distributions, a numerical and a binary target variable */
%macro simulate_big_data(library, data, N_observation, N_variables,
    influential = 0.6, categorical = 0.2, additional = 0.2, quantile = 0.65,
    noise = 0.1);
    /* Inputs: library: library where the output dataset is supposed to be */
    /*                  stored */
    /*         data: name of the output dataset */
    /*         N_observation: number of observations in the simulated */
    /*                        dataset */
    /*         N_variables: number of variables in the simulated dataset */
    /*         influential: proportion of variables which have an impact on */
    /*                      the target variable (default: 0.6) */
    /*         categorical: proportion of variables being transformed into */
    /*                      categorical variables */
    /*                      (default: 0.2) */
    /*         additional: proportion of additional variables only used for */
    /*                     constructing the target variable compared to */
    /*                     the number of influential variables being part of */
    /*                     the final dataset (default: 0.2) */
    /*         quantile: quantile specifying a boundary for the */
    /*                   classification of the target (smaller values "0", */
    /*                   higher values "1"; default: 0.65) */
    /*         noise: fraction of observations for which the binary target is
    /*                exchanged (default: 0.05)
    /* Output: dataset containing N_observation observations and N_variables */
    /*         variables */
        
    /* Definition of macro variables needed for simulating a dataset */
    %let N_categorical = %sysevalf(&N_variables * &categorical);
    %let N_additional = %sysevalf(&N_variables * &additional);
    %let N_influence = %sysevalf(&N_variables * &influential);
    %let N_noise = %eval(&N_variables - &N_influence);
    %let N_influence_cat = %sysevalf(&N_categorical * &influential);
    %let N_noise_cat = %eval(&N_categorical - &N_influence_cat);
    %let N_influence_num = %eval(&N_influence - &N_influence_cat);
    %let N_noise_num = %eval(&N_noise - &N_noise_cat);
    %let N_model = %eval(&N_influence + &N_additional);
    %let N_sim = %sysevalf(&N_observation / 2);

    /* A dataset with 10000000 observations is constructed using two
    invocations of "proc iml", in each invocation 5000000 observations of the
    same multivariate normal distribution are generated. Only the random number
    seed for drawing from that distribution is different. */

    /* Invocation 1 (5000000 observations) */
    proc iml;
        
        /* Setting of an initializing random number seed */
        call randseed(1234, 1);

        /* Definition of independent influential variables by drawing
        random numbers from a multivariate normal distribution */
        means = j(&N_model, 1, 0);
        sd = j(&N_model, 1, 1);
        call randgen(sd, "exponential", 30);
        corr = j(&N_model, &N_model, 0.2);
        do i = 1 to nrow(corr);
            corr[i, i] = 1;
        end;
        cov = diag(sd) * corr * diag(sd);
        call randseed(1234, 1);
        data_model = RandNormal(&N_sim, means, cov);

        
        /* Calculation of the numeric target variable as weighted sum of
        all influential variables */
        weights = j(&N_model, 1, 0);
        weights_inter = j(&N_model / 2, 1, 0);
        call randseed(1234, 1);
        call randgen(weights, "uniform", 0, 1);
        call randseed(1234, 1);
        if &N_variables = 100 then
            call randgen(weights_inter, "uniform", 0, 0.07);
        if &N_variables = 500 then
            call randgen(weights_inter, "uniform", 0, 0.09);
        if &N_variables = 1000 then
            call randgen(weights_inter, "uniform", 0, 0.11);
        if &N_variables = 2000 then
            call randgen(weights_inter, "uniform", 0, 0.14);
        if &N_variables = 5000 then
            call randgen(weights_inter, "uniform", 0, 0.18);
        y = j(&N_sim, 1, 0);
        call randseed(1234, 1);
        call randgen(y, "normal", 0, 10);
        do k = 1 to &N_sim;
            do l = 1 to &N_model;
                y[k] = y[k] + weights[l] * data_model[k, l];
            end;
            do l = 1 to &N_model / 2;
                y[k] = y[k] + weights_inter[l] * data_model[k, l] *
                    data_model[k, l + &N_model / 2];
            end;
        end;

        /* Simulation of noise variables by drawing random numbers from a
        multivariate normal distribution */
        means_noise = j(&N_noise, 1, 0);
        sd_noise = j(&N_noise, 1, 1);
        call randseed(5678, 1);
        call randgen(means_noise, "uniform", -100, 100);
        call randseed(5678, 1);
        call randgen(sd_noise, "exponential", 30);
        corr_noise = j(&N_noise, &N_noise, 0.1);
        do i = 1 to nrow(corr_noise);
            corr_noise[i, i] = 1;
        end;
        cov_noise = diag(sd_noise) * corr_noise * diag(sd_noise);
        call randseed(1234, 1);
        data_noise = RandNormal(&N_sim, means_noise, cov_noise);

        /* Categorization of the specified proportion of variables */
        data_cat = data_model[, 1:&N_influence_cat] ||
            data_noise[, 1:&N_noise_cat]; 
        categories = j(&N_sim, &N_categorical, "1");
        call randseed(1234, 1);
        /* Two categories */
        do i = 1 to &N_categorical by 5;
            call randgen(quantile, "uniform", 0.1, 0.9);
            call qntl(q, data_cat[, i], quantile);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q then categories[k, i] = "1";
                if q < data_cat[k, i] then categories[k, i] = "2";
            end;
        end;
        do i = 2 to &N_categorical by 5;
            call randgen(quantile, "uniform", 0.1, 0.9);
            call qntl(q, data_cat[, i], quantile);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q then categories[k, i] = "1";
                if q < data_cat[k, i] then categories[k, i] = "2";
            end;
        end;
        /* Three categories */
        do i = 3 to &N_categorical by 5;
            call randseed(1234, 1);
            call randgen(quantile1, "uniform", 0.1, 0.45);
            call randgen(quantile2, "uniform", 0.55, 0.9);
            call qntl(q1, data_cat[, i], quantile1);
            call qntl(q2, data_cat[, i], quantile2);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q1 then categories[k, i] = "1"; 
                if q1 < data_cat[k, i] & data_cat[k, i] < q2 then
                    categories[k, i] = "2";
                if q2 < data_cat[k, i] then categories[k, i] = "3";
            end;
        end;
       /* Four categories */
       do i = 4 to &N_categorical by 5;
            call randgen(quantile1, "uniform", 0.1, 0.31);
            call randgen(quantile2, "uniform", 0.34, 0.55);
            call randgen(quantile3, "uniform", 0.58, 0.89);
            call qntl(q1, data_cat[, i], quantile1);
            call qntl(q2, data_cat[, i], quantile2);
            call qntl(q3, data_cat[, i], quantile3);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q1 then categories[k, i] = "1";
                if q1 < data_cat[k, i] & data_cat[k, i] < q2 then
                    categories[k, i] = "2";
                if q2 < data_cat[k, i] & data_cat[k, i] < q3 then
                    categories[k, i] = "3";
                if q3 < data_cat[k, i] then categories[k, i] = "4";
            end;
        end;
        /* Five categories */
        do i = 5 to &N_categorical by 10;
            call randgen(quantile1, "uniform", 0.12, 0.28);
            call randgen(quantile2, "uniform", 0.32, 0.48);
            call randgen(quantile3, "uniform", 0.52, 0.68);
            call randgen(quantile4, "uniform", 0.72, 0.88);
            call qntl(q1, data_cat[, i], quantile1);
            call qntl(q2, data_cat[, i], quantile2);
            call qntl(q3, data_cat[, i], quantile3);
            call qntl(q4, data_cat[, i], quantile4);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q1 then categories[k, i] = "1";
                if q1 < data_cat[k, i] & data_cat[k, i] < q2 then
                    categories[k, i] = "2";
                if q2 < data_cat[k, i] & data_cat[k, i] < q3 then
                    categories[k, i] = "3";
                if q3 < data_cat[k, i] & data_cat[k, i] < q4 then
                    categories[k, i] = "4";
                if q4 < data_cat[k, i] then categories[k, i] = "5";
            end;
        end;
        /* Eights categories */
        do i = 10 to &N_categorical by 10;
            call randgen(quantile1, "uniform", 0.1, 0.19);
            call randgen(quantile2, "uniform", 0.22, 0.31);
            call randgen(quantile3, "uniform", 0.34, 0.43);
            call randgen(quantile4, "uniform", 0.46, 0.55);
            call randgen(quantile5, "uniform", 0.58, 0.67);
            call randgen(quantile6, "uniform", 0.7, 0.79);
            call randgen(quantile7, "uniform", 0.82, 0.91);
            call qntl(q1, data_cat[, i], quantile1);
            call qntl(q2, data_cat[, i], quantile2);
            call qntl(q3, data_cat[, i], quantile3);
            call qntl(q4, data_cat[, i], quantile4);
            call qntl(q5, data_cat[, i], quantile5);
            call qntl(q6, data_cat[, i], quantile6);
            call qntl(q7, data_cat[, i], quantile7);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q1 then categories[k, i] = "1";
                if q1 < data_cat[k, i] & data_cat[k, i] < q2 then
                    categories[k, i] = "2";
                if q2 < data_cat[k, i] & data_cat[k, i] < q3 then
                    categories[k, i] = "3";
                if q3 < data_cat[k, i] & data_cat[k, i] < q4 then
                    categories[k, i] = "4";
                if q4 < data_cat[k, i] & data_cat[k, i] < q5 then
                    categories[k, i] = "5";
                if q5 < data_cat[k, i] & data_cat[k, i] < q6 then
                    categories[k, i] = "6";
                if q6 < data_cat[k, i] & data_cat[k, i] < q7 then
                    categories[k, i] = "7";
                if q7 < data_cat[k, i] then categories[k, i] = "8";
            end;
        end;
        
        /* Construction of a binary target variable */
        y_target = j(&N_sim, 1, "0");
        call qntl(quantile, y, &quantile);
        do k = 1 to &N_sim;
            if y[k] < quantile then y_target[k] = "0";
            if y[k] > quantile then y_target[k] = "1";
        end;
        /* Random change of some values of the binary target */
        /* The number of observations for which the value are changed is
        supposed to be identical for both target classes. */
        y_binary = y_target;
        call randseed(1234, 1);
        random1 = j(&N_sim, 1, 0);
        random0 = j(&N_sim, 1, 0);
        call randgen(random1, "uniform");
        call randgen(random0, "uniform");
        do k = 1 to &N_sim;
            /* y_target = 1 -> y_binary = 0 */
            if y_target[k] = "1" & random1[k] <= (&noise / 2) /
                (1 - &quantile)
            then y_binary[k] = "0";
            /* y_target = 0 -> y_binary = 1 */
            if y_target[k] = "0" & random0[k] <= (&noise / 2) / &quantile
            then y_binary[k] = "1";
        end;
        
        /* Addition of constants to the continuous influential variables */
        means_inf = j(&N_model, 1, 0);
        call randseed(1234, 1);
        call randgen(means_inf, "uniform", -100, 100);
        do i = 1 to &N_model;
            data_model[, i] = data_model[, i] + means_inf[i];
        end;

        /* Creation of the final data matrix by putting together all
        components */
        data_model = data_model[, (&N_influence_cat + 1):ncol(data_model)];
        data_noise = data_noise[, (&N_noise_cat + 1):ncol(data_noise)] || y;
        categories = categories || y_binary;

        /* Definition of column names for the output datasets */
        names_inf = "inf1":"inf&N_influence_num";
        names_additional = "additional1":"additional&N_additional";
        names_model = names_inf || names_additional;
        names_noise = "noise1":"noise&N_noise_num" || "y";
        names_cat = "cat1":"cat&N_categorical" || "y_binary";
    
        /* Transformation of the resulting matrix into a dataset */
        create &library..&data._1 from data_model[colname = names_model];
        append from data_model;
        close &library..&data._1;
        create data_noise from data_noise[colname = names_noise];
        append from data_noise;
        close data_noise;
        create categories from categories[colname = names_cat];
        append from categories;
        close categories;
    quit;

    /* Removal of the variables which have been used for constructing the
    target variable, but are not part of the final dataset */
    data &library..&data._1;
        merge &library..&data._1 data_noise categories;
        drop additional1--additional&N_additional;
    run;

    /* Invocation 2 (5000000 observations) */
    proc iml;
        
        /* Setting of an initializing random number seed */
        call randseed(1234, 1);

        /* Definition of independent influential variables by drawing
        random numbers from a multivariate normal distribution */
        means = j(&N_model, 1, 0);
        sd = j(&N_model, 1, 1);
        call randgen(sd, "exponential", 30);
        corr = j(&N_model, &N_model, 0.2);
        do i = 1 to nrow(corr);
            corr[i, i] = 1;
        end;
        cov = diag(sd) * corr * diag(sd);
        call randseed(5678, 1);
        data_model = RandNormal(&N_sim, means, cov);

        
        /* Calculation of the numeric target variable as weighted sum of
        all influential variables */
        weights = j(&N_model, 1, 0);
        weights_inter = j(&N_model / 2, 1, 0);
        call randseed(1234, 1);
        call randgen(weights, "uniform", 0, 1);
        call randseed(1234, 1);
        if &N_variables = 100 then
            call randgen(weights_inter, "uniform", 0, 0.07);
        if &N_variables = 500 then
            call randgen(weights_inter, "uniform", 0, 0.09);
        if &N_variables = 1000 then
            call randgen(weights_inter, "uniform", 0, 0.11);
        if &N_variables = 2000 then
            call randgen(weights_inter, "uniform", 0, 0.14);
        if &N_variables = 5000 then
            call randgen(weights_inter, "uniform", 0, 0.18);
        y = j(&N_sim, 1, 0);
        call randseed(1234, 1);
        call randgen(y, "normal", 0, 10);
        do k = 1 to &N_sim;
            do l = 1 to &N_model;
                y[k] = y[k] + weights[l] * data_model[k, l];
        end;
        do l = 1 to &N_model / 2;
            y[k] = y[k] + weights_inter[l] * data_model[k, l] *
                data_model[k, l + &N_model / 2];
            end;
        end;

        /* Simulation of noise variables by drawing random numbers from a
        multivariate normal distribution */
        means_noise = j(&N_noise, 1, 0);
        sd_noise = j(&N_noise, 1, 1);
        call randseed(5678, 1);
        call randgen(means_noise, "uniform", -100, 100);
        call randseed(5678, 1);
        call randgen(sd_noise, "exponential", 30);
        corr_noise = j(&N_noise, &N_noise, 0.1);
        do i = 1 to nrow(corr_noise);
            corr_noise[i, i] = 1;
        end;
        cov_noise = diag(sd_noise) * corr_noise * diag(sd_noise);
        call randseed(1234, 1);
        data_noise = RandNormal(&N_sim, means_noise, cov_noise);

        /* Categorization of the specified proportion of variables */
        data_cat = data_model[, 1:&N_influence_cat] ||
            data_noise[, 1:&N_noise_cat]; 
        categories = j(&N_sim, &N_categorical, "1");
        call randseed(1234, 1);
        /* Two categories */
        do i = 1 to &N_categorical by 5;
            call randgen(quantile, "uniform", 0.1, 0.9);
            call qntl(q, data_cat[, i], quantile);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q then categories[k, i] = "1";
                if q < data_cat[k, i] then categories[k, i] = "2";
            end;
        end;
        do i = 2 to &N_categorical by 5;
            call randgen(quantile, "uniform", 0.1, 0.9);
            call qntl(q, data_cat[, i], quantile);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q then categories[k, i] = "1";
                if q < data_cat[k, i] then categories[k, i] = "2";
            end;
        end;
        /* Three categories */
        do i = 3 to &N_categorical by 5;
            call randseed(1234, 1);
            call randgen(quantile1, "uniform", 0.1, 0.45);
            call randgen(quantile2, "uniform", 0.55, 0.9);
            call qntl(q1, data_cat[, i], quantile1);
            call qntl(q2, data_cat[, i], quantile2);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q1 then categories[k, i] = "1"; 
                if q1 < data_cat[k, i] & data_cat[k, i] < q2 then
                    categories[k, i] = "2";
                if q2 < data_cat[k, i] then categories[k, i] = "3";
            end;
        end;
       /* Four categories */
       do i = 4 to &N_categorical by 5;
            call randgen(quantile1, "uniform", 0.1, 0.31);
            call randgen(quantile2, "uniform", 0.34, 0.55);
            call randgen(quantile3, "uniform", 0.58, 0.89);
            call qntl(q1, data_cat[, i], quantile1);
            call qntl(q2, data_cat[, i], quantile2);
            call qntl(q3, data_cat[, i], quantile3);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q1 then categories[k, i] = "1";
                if q1 < data_cat[k, i] & data_cat[k, i] < q2 then
                    categories[k, i] = "2";
                if q2 < data_cat[k, i] & data_cat[k, i] < q3 then
                    categories[k, i] = "3";
                if q3 < data_cat[k, i] then categories[k, i] = "4";
            end;
        end;
        /* Five categories */
        do i = 5 to &N_categorical by 10;
            call randgen(quantile1, "uniform", 0.12, 0.28);
            call randgen(quantile2, "uniform", 0.32, 0.48);
            call randgen(quantile3, "uniform", 0.52, 0.68);
            call randgen(quantile4, "uniform", 0.72, 0.88);
            call qntl(q1, data_cat[, i], quantile1);
            call qntl(q2, data_cat[, i], quantile2);
            call qntl(q3, data_cat[, i], quantile3);
            call qntl(q4, data_cat[, i], quantile4);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q1 then categories[k, i] = "1";
                if q1 < data_cat[k, i] & data_cat[k, i] < q2 then
                    categories[k, i] = "2";
                if q2 < data_cat[k, i] & data_cat[k, i] < q3 then
                    categories[k, i] = "3";
                if q3 < data_cat[k, i] & data_cat[k, i] < q4 then
                    categories[k, i] = "4";
                if q4 < data_cat[k, i] then categories[k, i] = "5";
            end;
        end;
        /* Eights categories */
        do i = 10 to &N_categorical by 10;
            call randgen(quantile1, "uniform", 0.1, 0.19);
            call randgen(quantile2, "uniform", 0.22, 0.31);
            call randgen(quantile3, "uniform", 0.34, 0.43);
            call randgen(quantile4, "uniform", 0.46, 0.55);
            call randgen(quantile5, "uniform", 0.58, 0.67);
            call randgen(quantile6, "uniform", 0.7, 0.79);
            call randgen(quantile7, "uniform", 0.82, 0.91);
            call qntl(q1, data_cat[, i], quantile1);
            call qntl(q2, data_cat[, i], quantile2);
            call qntl(q3, data_cat[, i], quantile3);
            call qntl(q4, data_cat[, i], quantile4);
            call qntl(q5, data_cat[, i], quantile5);
            call qntl(q6, data_cat[, i], quantile6);
            call qntl(q7, data_cat[, i], quantile7);
            do k = 1 to &N_sim;
                if data_cat[k, i] < q1 then categories[k, i] = "1";
                if q1 < data_cat[k, i] & data_cat[k, i] < q2 then
                    categories[k, i] = "2";
                if q2 < data_cat[k, i] & data_cat[k, i] < q3 then
                    categories[k, i] = "3";
                if q3 < data_cat[k, i] & data_cat[k, i] < q4 then
                    categories[k, i] = "4";
                if q4 < data_cat[k, i] & data_cat[k, i] < q5 then
                    categories[k, i] = "5";
                if q5 < data_cat[k, i] & data_cat[k, i] < q6 then
                    categories[k, i] = "6";
                if q6 < data_cat[k, i] & data_cat[k, i] < q7 then
                    categories[k, i] = "7";
                if q7 < data_cat[k, i] then categories[k, i] = "8";
            end;
        end;
        
        /* Construction of a binary target variable */
        y_target = j(&N_sim, 1, "0");
        call qntl(quantile, y, &quantile);
        do k = 1 to &N_sim;
            if y[k] < quantile then y_target[k] = "0";
            if y[k] > quantile then y_target[k] = "1";
        end;
        /* Random change of some values of the binary target */
        /* The number of observations for which the value are changed is
        supposed to be identical for both target classes. */
        y_binary = y_target;
        call randseed(1234, 1);
        random1 = j(&N_sim, 1, 0);
        random0 = j(&N_sim, 1, 0);
        call randgen(random1, "uniform");
        call randgen(random0, "uniform");
        do k = 1 to &N_sim;
            /* y_target = 1 -> y_binary = 0 */
            if y_target[k] = "1" & random1[k] <= (&noise / 2) /
                (1 - &quantile)
            then y_binary[k] = "0";
            /* y_target = 0 -> y_binary = 1 */
            if y_target[k] = "0" & random0[k] <= (&noise / 2) / &quantile
            then y_binary[k] = "1";
        end;
        
        /* Addition of constants to the continuous influential variables */
        means_inf = j(&N_model, 1, 0);
        call randseed(1234, 1);
        call randgen(means_inf, "uniform", -100, 100);
        do i = 1 to &N_model;
            data_model[, i] = data_model[, i] + means_inf[i];
        end;

        /* Creation of the final data matrix by putting together all
        components */
        data_model = data_model[, (&N_influence_cat + 1):ncol(data_model)];
        data_noise = data_noise[, (&N_noise_cat + 1):ncol(data_noise)] || y;
        categories = categories || y_binary;

        /* Definition of column names for the output datasets */
        names_inf = "inf1":"inf&N_influence_num";
        names_additional = "additional1":"additional&N_additional";
        names_model = names_inf || names_additional;
        names_noise = "noise1":"noise&N_noise_num" || "y";
        names_cat = "cat1":"cat&N_categorical" || "y_binary";
    
        /* Transformation of the resulting matrix into a dataset */
        create &library..&data._2 from data_model[colname = names_model];
        append from data_model;
        close &library..&data._2;
        create data_noise from data_noise[colname = names_noise];
        append from data_noise;
        close data_noise;
        create categories from categories[colname = names_cat];
        append from categories;
        close categories;
    quit;

    /* Removal of the variables which have been used for constructing the
    target variable, but are not part of the final dataset */
    data &library..&data._2;
        merge &library..&data._2 data_noise categories;
        drop additional1--additional&N_additional;
    run;

    /* Merging of both parts of the final dataset */
    data &library..&data;
        set &library..&data._1 &library..&data._2;
    run;
%mend;

%simulate_big_data(data, simulated_Row7000_Col1500, 7000, 1500,
    influential = 0.6, categorical = 0.2, additional = 0.2, quantile = 0.65,
    noise = 0.1);
/* Generate synthetic data for collinearity analysis and logistic regression. */
data hpadata.sim_data;
	array _a{8} _temporary_ (0,0,0,1,0,1,1,1);
	array _b{8} _temporary_ (0,0,1,0,1,0,1,1);
	array _c{8} _temporary_ (0,1,0,0,1,1,0,1);

	do obsno=1 to 10000000;
		/* Returns a random variate from a tabled probability distribution. */
		x = rantbl(1,0.28,0.18,0.14,0.14,0.03,0.09,0.08,0.06);
		a = _a{x};
		b = _b{x};
		c = _c{x};
		x1 = int(ranuni(1)*400);
		x2 = 52 + ranuni(1)*38;
		x3 = ranuni(1)*12;
		lp = 6. -0.015*(1-a) + 0.7*(1-b) + 0.6*(1-c) + 0.02*x1 - 0.05*x2 - 0.1*x3;

		/* Returns a random variate from a binomial distribution. */
		y = ranbin(1,1,(1/(1+exp(lp))));
		output;
	end;

	drop x lp;
run;
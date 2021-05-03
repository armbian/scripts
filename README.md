 - cacherebuild.sh is a script which can run at PUSH + once per day. It regenerates cache:
	 - all cache 4 days before end of the month (for next month) which is enough that cache is sync across our network
	 - changed cache where packages were changed
	 - needs to be run privately since signing keys are needed (optional cache can be signed elsewhere)
 - ubootrebuild.sh builds all u-boots. 
	 - Can be ran manually - before starting testing new release.
	 - can run on public server


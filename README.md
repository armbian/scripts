<p align="center">
  <a href="#build-framework">
  <img src="https://raw.githubusercontent.com/armbian/build/master/.github/armbian-logo.png" alt="Armbian logo" width="144">
  </a><br>
  <strong>Armbian Linux CI Infrastructure</strong><br>
<br>
<img alt="GitHub Workflow Status" src="https://img.shields.io/badge/dynamic/json?label=CPU%20COUNT&query=CPU&cacheSeconds=10&style=for-the-badge&url=https%3A%2F%2Fgithub.com%2Farmbian%2Fscripts%2Freleases%2Fdownload%2Fstatus%2Frunners_capacity.json"> <img alt="GitHub Workflow Status" src="https://img.shields.io/badge/dynamic/json?label=MEMORY&query=MEM&cacheSeconds=10&style=for-the-badge&url=https%3A%2F%2Fgithub.com%2Farmbian%2Fscripts%2Freleases%2Fdownload%2Fstatus%2Frunners_capacity.json">
</p>
 
 - cacherebuild.sh is a script which can run at PUSH + once per day. It regenerates cache:
	 - all cache 4 days before end of the month (for next month) which is enough that cache is sync across our network
	 - changed cache where packages were changed
	 - gpg signing should be done elsewhere
 - ubootrebuild.sh builds all u-boots. 
	 - Can be ran manually - before starting testing new release.
	 - can run on public server
 - betarepository.sh builds all kernels if changed
	 - only builds changed kernels
	 - always build BSP
	 - bump nighly version
	 - update repository
 - selected-images.sh builds image for or more boards


# VERSION

- bug fix releases for selected images
- new stable images added after major release
- BSP will be recreated for all and pushed to stable repository
- build artefacts for selected builds will also be pushed to stable repository

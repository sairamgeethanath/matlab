function [ims imsos d]= recon3dft(pfile,echo,readoutfile,dokzft,zpad,dodisplay,clim)
% function [ims imsos]= recon3dft(pfile,echo,readoutfile)
%
% Recon 3D spin-warp image acquired with toppe.
% Supports multiple 3D images, each saved in different (dab)echo.
%
% Input:
%  echo:         echo to recon
%
% Output:
%  ims:          [nx ny nz ncoils]    
%
% $Id: recon3dft.m,v 1.17 2017/11/02 17:36:28 jfnielse Exp $

if ~exist('echo','var')
	echo = 1;
end
if ~exist('readoutfile','var')
	readoutfile = 'readout.mod';
end
if ~exist('dokzft','var')
	dokzft = true;
end
if ~exist('dodisplay','var')
	dodisplay = 1;
end
if ~exist('zpad','var')
	zpad = [1 1];     % zero-padding factor along z
end

% load raw data
addpath /net/brooks/export/home/jfnielse/github/toppe/matlab/lib/GE   % loadpfile.m
d = loadpfile(pfile,echo);   % int16. [ndat ncoils nslices nechoes nviews] = [ndat ncoils nz 2 ny]
d = permute(d,[1 5 3 2 4]);         % [ndat ny nz ncoils nechoes]
d = double(d);

d = flipdim(d,1);        % data is stored in reverse order for some reason

%if(mod(size(d,3),2))
%	d = d(:,:,2:end,:,:);  % throw away dabslice = 0
%end

% get flat portion of readout
addpath /net/brooks/export/home/jfnielse/github/toppe/matlab/lib      % readmod.m
[desc,rho,theta,gx,gy,gz,paramsint16,paramsfloat] = readmod(readoutfile);
nramp = 0; %15;  % see mat2mod.m
nbeg = paramsint16(3) + nramp;  
nx = paramsint16(4);  % number of acquired data samples per TR
decimation = paramsint16(10);
d = d(nbeg:(nbeg+nx-1),:,:,:,:);     % [nx*125/oprbw ny nz ncoils nechoes]

% zero-pad in z
if zpad(2) > 1
	[ndat ny nz ncoils nechoes] = size(d);
	d2 = zeros([ndat ny round(nz*zpad(2)) ncoils]);
	d2(:,:,(end/2-nz/2):(end/2+nz/2-1),:,:) = d;
	d = d2; clear d2;
end

% recon 
for coil = 1:size(d,4)
	fprintf(1,'\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\brecon coil %d', coil);
	imstmp = ift3(d(:,:,:,coil),dokzft);
	imstmp = imstmp(end/2+((-nx/decimation/2):(nx/decimation/2-1))+1,:,:);               % [nx ny nz]
	if zpad(1) > 1   % zero-pad (interpolate) in xy
		dtmp = fft3(imstmp);
		[nxtmp nytmp nztmp] = size(dtmp);
		dtmp2 = zeros([round(nxtmp*zpad(1)) round(nytmp*zpad(1)) nztmp]);
		dtmp2((end/2-nxtmp/2):(end/2+nxtmp/2-1),(end/2-nytmp/2):(end/2+nytmp/2-1),:) = dtmp;
		dtmp = dtmp2; clear dtmp2;
		imstmp = ift3(dtmp);
	end
	ims(:,:,:,coil) = imstmp;
end

fprintf('\n');

%ims = flipdim(ims,1);

% display root sum-of-squares image
imsos = sqrt(sum(abs(ims).^2,4)); 
%figure; im('blue0',imsos,[0 1.3]);
if exist('clim','var')
	if dodisplay
		%im(permute(imsos,[2 1 3]),clim);
		im(imsos,clim);
	end
else
	if dodisplay
		%im(permute(imsos,[2,1,3]));
		im(imsos);
	end
end
return;

function im = ift3(D,do3dfft)
%
%	function im = ift3(dat)
%
%	Centered inverse 3DFT of a 3D data matrix.
% 
% $Id: ift3.m,v 1.1 2017/08/02 21:14:20 jfnielse Exp $

if ~exist('do3dfft','var')
	do3dfft = true;
end

if do3dfft
	im = fftshift(ifftn(fftshift(D)));
else
	% don't do fft in 3rd dimension
	for k = 1:size(D,3)
		im(:,:,k) = fftshift(ifftn(fftshift(D(:,:,k))));
	end
end

return;

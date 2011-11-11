%% ** Grid Refinement Demo **
% Given a banded coarse grid, we can refine it to finer and finer
% grids MUCH faster than generating from scratch and without building
% big meshgrids (the only fully nD embedding space grid will be at the
% coarest level---which can be negliable).

% Include the cp_matrices folder (edit as appropriate)
addpath('../cp_matrices');

% add functions for finding the closest points
addpath('../surfaces');


tic
%% Find an initial coarse band of closest points
% '_c' to indicate "coarse"
dx = 0.2;
% Mobius strip
cpf1 = @cpMobiusStrip;  paramf = @paramMobiusStrip;
x1d_c = ((-1-6*dx):dx:(1+6*dx))';
y1d_c = x1d_c;
z1d_c = ((-0.5-6*dx):dx:(0.5+6*dx))';
% Hemisphere
%cpf1 = @cpHemisphere;  paramf = @paramHemisphere;
%x1d_c = ((-1-5*dx):dx:(1+5*dx))';
%y1d_c = ((-1-6*dx):dx:(1+6*dx))';
%z1d_c = (( 0-7*dx):dx:(1+7*dx))';


% cpbar for boundary conditions
cpf = @(x,y,z) cpbar_3d(x, y, z, cpf1);
%cpf = cpf1;


disp('starting initial coarse');
% meshgrid is only needed at this coarse grid
[xxc, yyc, zzc] = meshgrid(x1d_c, y1d_c, z1d_c);

[cpx_c, cpy_c, cpz_c, dist_c, bdy_c] = cpf(xxc,yyc,zzc);


% Bandwidth formula
dim = 3;  % dimension
p = 3;    % interpolation order
% "band" is a vector of the indices of the points in the computation
% band.  The formula for bw is found in [Ruuth & Merriman 2008] and
% the 1.0001 is a safety factor.
bw = 1.0001*sqrt((dim-1)*((p+1)/2)^2 + ((1+(p+1)/2)^2));

% actually banding the coarse grid is optional, you can pass the
% entire grid to refine_grid() and the result will be banded according
% to "bw".  So either of these is ok:
%band_c = find(abs(dist_c) <= bw*dx);
band_c = ( 1:length(xxc(:)) )';


% store closest points in the band (can discard others)
cpx_c = cpx_c(band_c); cpy_c = cpy_c(band_c); cpz_c = cpz_c(band_c);
x_c = xxc(band_c); y_c = yyc(band_c); z_c = zzc(band_c);
dist_c = dist_c(band_c);
bdy_c = bdy_c(band_c);

clear xxc yyc zzc

time_ini = toc


%figure(2); clf;
%porcupine_plot3d_param(x_c,y_c,z_c, cpx_c,cpy_c,cpz_c, bdy_c, paramf, 2)
%view(3)
%camlight left


dx_c = dx;   % store the coarse dx

%% refine it twice
disp('starting refinement');
A = tic;
[band,x,y,z,cpx,cpy,cpz,dist,bdy,dx,x1d,y1d,z1d] = refine_grid(2, cpf, dx_c, x1d_c, y1d_c, z1d_c, bw, band_c, dist_c, bdy_c);
%dx2 = dx/2^1;
time_refine_total = toc(A)

%figure(3); clf;
%porcupine_plot3d_param(x,y,z, cpx,cpy,cpz, bdy, paramf, 3)
%view(3)
%camlight left


function [E,Ej,Es] = interpn_matrix(xs, xi, p, band)
%INTERPN_MATRIX  Return a n-D interpolation matrix
%   E = INTERPN_MATRIX(X, XI, P)
%   E = INTERPN_MATRIX({X Y Z ... W}, [XI YI ZI ... WI], P)
%   E = INTERPN_MATRIX({X Y Z ... W}, {XI YI ZI ... WI}, P)  (TODO)
%   Build a matrix which interpolates grid data on a grid defined by
%   the product of the lists X onto the points specified by columns
%   of XI.
%   Interpolation is done using degree P barycentric Lagrange
%   interpolation.  E will be a 'size(XI,1)' by M sparse matrix
%   where M is the product of the lengths of X, Y, Z, ..., W.
%
%   E = INTERPN_MATRIX(X, XI, P, BAND)
%   BAND is a list of linear indices into a (possibly fictious) n-D
%   array of points constructed with *ndgrid*.  Here the columns of E
%   that are not in BAND are discarded.  This is done by first
%   constructing E as above.  E will be a 'size(XI,1)' by
%   'length(BAND)' sparse matrix.
%
%   [Ei,Ej,Es] = INTERPN_MATRIX(...)
%   [Ei,Ej,Es] = INTERPN_MATRIX(...)
%   Here the entries of the matrix are returned as three vectors
%   (like in FEM).  This is efficient and avoids the overhead of
%   constructing the matrix.  If BAND is passed or not determines
%   the column space of the result (i.e., effects Ej).
%   (TODO: with BAND currently not implemented).
%
%   Does no error checking up the equispaced nature of x,y,z


  if (1==0)  % TODO: none for now
  % input checking
  [temp1, temp2] = size(x);
  if ~(  (ndims(x) == 2) && (temp1 == 1 || temp2 == 1)  )
    error('x must be a vector, not e.g., meshgrid output');
  end
  [temp1, temp2] = size(y);
  if ~(  (ndims(y) == 2) && (temp1 == 1 || temp2 == 1)  )
    error('y must be a vector, not e.g., meshgrid output');
  end
  [temp1, temp2] = size(z);
  if ~(  (ndims(z) == 2) && (temp1 == 1 || temp2 == 1)  )
    error('z must be a vector, not e.g., meshgrid output');
  end
  if ~(  (ndims(xi) == 2) && (size(xi,2) == 1)  )
    error('xi must be a column vector');
  end
  if ~(  (ndims(yi) == 2) && (size(yi,2) == 1)  )
    error('yi must be a column vector');
  end
  if ~(  (ndims(zi) == 2) && (size(zi,2) == 1)  )
    error('zi must be a column vector');
  end
  end

  if (nargin == 2)
    p = 3
    makeBanded = false;
  elseif (nargin == 3)
    makeBanded = false;
  elseif (nargin == 4)
    makeBanded = true;
  else
    error('unexpected inputs');
  end

  if (nargout > 1)
    makeListOutput = true;
  else
    makeListOutput = false;
  end

  if makeBanded && makeListOutput
    error('currently cannot make both Banded and Ei,Ej,Es output');
  end

  T = tic;
  dim = length(xs);
  Ns = zeros(1, dim);
  ddx = zeros(1, dim);
  ptL = zeros(1, dim);
  for d=1:dim
    Ns(d) = length(xs{d});
    ddx(d) = xs{d}(2)-xs{d}(1);
    ptL(d) = xs{d}(1);
  end

  if (prod(Ns) > 1e15)
    error('too big to use doubles as indicies: implement int64 indexing')
  end

  N = p+1;
  EXTSTENSZ = N^dim;

  Ni = length(xi(:,1));

  %tic
  Ei = repmat((1:Ni)',1,EXTSTENSZ);
  Ej = zeros(size(Ei));
  weights = zeros(size(Ei));
  %toc

  %tic
  % this used to be a call to buildInterpWeights but now most of
  % that is done here
  [Ibpt, Xgrid] = findGridInterpBasePt_vec(xi, p, ptL, ddx);
  xw = {};
  for d=1:dim
    xw{d} = LagrangeWeights1D_vec(Xgrid(:,d), xi(:,d), ddx(d), N);
  end
  %toc

  NN = N*ones(1,d);
  %tic
  for s=1:prod(NN);
    ii = myind2sub(NN, s);  % need *not* match meshgrid/ndgrid usage
    %weights(:,s) = xw(:,i) .* yw(:,j) .* zw(:,k);
    temp = xw{1}(:,ii(1));
    for d=2:dim
      temp = temp .* xw{d}(:,ii(d));
    end
    weights(:,s) = temp;

    for d=1:dim
      gi{d} = (Ibpt(:,d) + ii(d) - 1);
    end

    % all these do the same, but last one is fastest.  Although sub2ind
    % presumably has safety checks...
    %ind = (gk-1)*(Nx*Ny) + (gi-1)*Ny + gj;
    ind = sub2ind(Ns, gi{:});
    %ind = round((gk-1)*(Nx*Ny) + (gi-1)*(Ny) + gj-1 + 1);
    Ej(:,s) = ind;
  end
  %toc
  T1 = toc(T);
  %fprintf('done new Ei,Ej,weights, total time: %g\n', T1);


  % TODO: is there any advantage to keeping Ei as matrices?  Then each
  % column corresponds to the same point in the stencil...
  if ~makeListOutput
    tic
    E = sparse(Ei(:), Ej(:), weights(:), Ni, prod(Ns));
    T2 = toc;
    %fprintf('call to "sparse" time: %g\n', toc);
  end
  % Straightening them first doesn't make it faster
  %tic
  %Ei = Ei(:);
  %Ej = Ej(:);
  %weights = weights(:);
  %toc
  %tic
  %E = sparse(Ei, Ej, weights, length(xi), Nx*Ny*Nz);
  %toc

  if (makeBanded)
    %disp('band the large matrix:');
    if (1==1)
      %tic
      E = E(:,band);
      %toc
    else
      % sanity check: the columns outside of band should all be zero
      tic
      Esparse = E(:,band);
      Eout = E(:,setdiff(1:(Nx*Ny*Nz),band));
      if (nnz(Eout) > 0)
        nnz(Eout)
        warning('Lost some non-zero coefficients (from outside the innerband)');
      end
      E = Esparse;
      toc
    end
  end

  if (1==0)
    disp('[testing] get back components:');
    tic; [I,J,V] = find(Es); toc

    disp('call "sparse" on smaller system:');
    tic; Es2 = sparse(I, J, V, length(xi), length(band)); toc
    E-Es2
  end

  if (1==0)
    % TODO: do this outside in another function
    disp('banding 2: this way finds innerband');
    %tic
    %innerband = unique(Ej(:));
    %toc
    tic
    [innerband,I,J] = unique(Ej(:));
    toc
    tic
    Es3 = sparse(Ei(:), J, weights(:), length(xi),length(innerband));
    toc
    %keyboard
  end

  if (makeListOutput)
    E = Ei(:);   % first output is called E
    Ej = Ej(:);
    Es = weights(:);
  end
end


function A = myind2sub(siz, ndx)
% ndx is the linear index
  n = length(siz);
  n = length(siz);
  k = [1 cumprod(siz(1:end-1))];
  for i = n:-1:1,
    vi = rem(ndx-1, k(i)) + 1;
    vj = (ndx - vi)/k(i) + 1;
    A(i) = vj;
    ndx = vi;
  end
end

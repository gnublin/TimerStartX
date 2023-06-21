// MIT License
// Copyright (c) 2022 Gauthier FRANCOIS

detectIncognito().then((result) => {
  if (result.isPrivate)
  {
    window.location.href = "/vote?error=true";
  }
});
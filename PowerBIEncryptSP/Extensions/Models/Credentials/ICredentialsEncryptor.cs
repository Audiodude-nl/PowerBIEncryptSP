using System;
using System.Collections.Generic;
using System.Text;

namespace PowerBIEncryptSP.Extensions.Models.Credentials
{
    public interface ICredentialsEncryptor
    {
        string EncodeCredentials(string plainText);
    }
}

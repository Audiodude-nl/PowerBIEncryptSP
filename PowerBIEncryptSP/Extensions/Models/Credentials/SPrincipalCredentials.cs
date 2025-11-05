namespace PowerBIEncryptSP.Models.Credentials
{
    /// <summary>
    /// ServicePrincipal based datasource credentials
    /// </summary>
    public abstract class SPrincipalCredentials : CredentialsBase
    {
        private const string TENANTID = "tenantId";
        private const string SERVICEPRINCIPALCLIENTID = "servicePrincipalClientId";
        private const string SERVICEPRINCIPALSECRET = "servicePrincipalSecret";

        /// <summary>
        /// Initializes a new instance of the SPrincipalCredentials class.
        /// </summary>
        /// <param name="tenantId">The tenantId</param>
        /// <param name="servicePrincipalClientId">The servicePrincipalClientId</param>
        /// <param name="servicePrincipalSecret">The servicePrincipalSecret</param>
        public SPrincipalCredentials(string tenantId, string servicePrincipalClientId, string servicePrincipalSecret)
        {
            // if (string.IsNullOrEmpty(tenantId))
            // {
            //     throw new ValidationException(ValidationRules.CannotBeNull, TENANTID);
            // }
            // if (string.IsNullOrEmpty(servicePrincipalClientId))
            // {
            //     throw new ValidationException(ValidationRules.CannotBeNull, SERVICEPRINCIPALCLIENTID);
            // }
            // if (string.IsNullOrEmpty(servicePrincipalSecret))
            // {
            //     throw new ValidationException(ValidationRules.CannotBeNull, SERVICEPRINCIPALSECRET);
            // }

            this.CredentialData[TENANTID] = tenantId;
            this.CredentialData[SERVICEPRINCIPALCLIENTID] = servicePrincipalClientId;
            this.CredentialData[SERVICEPRINCIPALSECRET] = servicePrincipalSecret;
        }
    }
}

namespace PowerBIEncryptSP.Models.Credentials
{
    /// <summary>
    /// tenantId, ApplicationId and clientsecret based datasource credentials to be used in service principal authentication
    /// </summary>
    public class ServicePrincipalCredentials : SPrincipalCredentials
    {
        /// <summary>
        /// Initializes a new instance of the ServicePrincipalCredentials class.
        /// </summary>
        /// <param name="tenantId">The tenantId</param>
        /// <param name="servicePrincipalClientId">The servicePrincipalClientId</param>
        /// <param name="servicePrincipalSecret">The servicePrincipalSecret</param>
        public ServicePrincipalCredentials(string tenantId, string servicePrincipalClientId , string servicePrincipalSecret ) : base(tenantId, servicePrincipalClientId, servicePrincipalSecret) { }

        internal override CredentialType CredentialType { get => CredentialType.ServicePrincipal; }
    }
}
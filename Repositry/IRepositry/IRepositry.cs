using System.Linq.Expressions;

namespace MagicVilla_VillaAPI.Repositry.IRepositry
{
    public interface IRepositry <T> where T : class
    {
        Task<List<T>> GetAllAsync(Expression<Func<T, bool>> ?  filter = null);

        Task<T> GetAsync(Expression<Func<T, bool>> filter = null, bool tracked = true);

        Task CreateAsync(T entity);

        Task RemoveAsync(T entity);

        Task SaveAsync();
    }
}

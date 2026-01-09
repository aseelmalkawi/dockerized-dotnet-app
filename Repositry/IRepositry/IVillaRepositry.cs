using MagicVilla_VillaAPI.Models;
using System.Linq.Expressions;

namespace MagicVilla_VillaAPI.Repositry.IRepositry
{
    public interface IVillaRepositry : IRepositry<Villa>
    {

        Task <Villa> UpdateAsync(Villa entity);


    }
}
